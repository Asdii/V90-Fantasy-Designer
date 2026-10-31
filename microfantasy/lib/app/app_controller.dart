import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../models/job_progress.dart';
import '../repositories/key_value_store.dart';
import '../repositories/job_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/calibration_repository.dart';
import '../services/calibration/calibration_service.dart';
import '../services/esp32/mock_esp32_service.dart';
import '../services/esp32/websocket_esp32_service.dart';
import '../services/esp32/esp32_discovery.dart';
import '../services/fantasy_designer/fantasy_designer_service.dart';
import '../services/file_transfer.dart';
import '../services/updates/app_update_service.dart';
import 'update_controller.dart';

class AppController extends ChangeNotifier {
  AppController({
    required this.store,
    required this.designer,
    FileTransfer? files,
    AppUpdateService updateService = const UnsupportedUpdateService(),
  }) : files = files ?? FileTransfer(),
       updates = UpdateController(store, updateService),
       jobs = JobRepository(store),
       preferences = SettingsRepository(store),
       calibrations = CalibrationRepository(store);
  final KeyValueStore store;
  final FantasyDesignerService designer;
  final FileTransfer files;
  final UpdateController updates;
  final JobRepository jobs;
  final SettingsRepository preferences;
  final CalibrationRepository calibrations;
  final CalibrationService calibration = const CalibrationService();
  final Esp32Discovery discovery = Esp32Discovery(
    serviceType: '_fantasy-machine._tcp',
  );
  Esp32Service? _esp;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  StreamSubscription<Esp32Position>? _positionSub;
  StreamSubscription<Esp32Status>? _statusSub;
  Timer? _freshness;
  AppSettings settings = AppSettings();
  List<CalibrationProfile> profiles = [];
  JobProgress? progress;
  CuttingJob? pendingJob;
  int calibrationIndex = 0;
  int calibrationSavedId = 0;
  double? lastSavedCalibrationAngle;
  int _calibrationRevision = 0;
  bool _foreground = true;
  Future<void> _receiverLifecycle = Future<void>.value();
  String helperDirection = 'horizontal';
  bool helperZeroView = false;
  double? rawX;
  DateTime? _lastPosition;
  bool busy = false;
  bool ready = false;
  bool _arrived = false;
  bool _disposed = false;
  String? notice;
  int noticeId = 0;
  Future<void> _writes = Future<void>.value();
  Future<void> _connections = Future<void>.value();
  Future<void> _receipts = Future<void>.value();
  int _connecting = 0;
  CuttingJob? get job => progress?.job;
  CuttingStep? get step => progress?.current;
  int get stepIndex => progress?.index ?? 0;
  CalibrationProfile get profile => profiles.single;
  List<double> get angles => calibration.sampleAngles(settings.angleInterval);
  double get calibrationAngle =>
      angles[calibrationIndex.clamp(0, angles.length - 1)];
  bool get hasCalibrationReference =>
      profiles.isNotEmpty && profile.points.any((p) => p.angleR == 0);
  bool get compensationActive =>
      hasCalibrationReference && profile.points.length >= 2;
  double getXOffsetForAngle(double angle) =>
      compensationActive ? calibration.offsetAt(profile, angle) : 0;
  double getCorrectedTargetX(CuttingStep step) =>
      step.x + getXOffsetForAngle(step.angleR);
  double get correctedTarget => step == null ? 0 : getCorrectedTargetX(step!);
  double? get actualX {
    if (!(_esp?.currentStatus.isConnected ?? false) ||
        rawX == null ||
        _lastPosition == null ||
        DateTime.now().difference(_lastPosition!) > settings.timeout) {
      return null;
    }
    return rawX! * (settings.invertX ? -1 : 1);
  }

  String get connectionLabel => settings.simulation
      ? 'Simulación'
      : actualX != null
      ? 'Conectado'
      : 'Desconectado · esperando lectura';
  bool get receiverSupported => designer.supportsNativeReceiver;
  bool get receiving => designer.currentStatus.isRunning;
  String get receiverLabel =>
      receiving ? 'Disponible para recibir' : 'No detectado';
  String get receiverAddress => designer.endpoints.isEmpty
      ? 'Conecta el teléfono a tu Wi-Fi para ver su dirección.'
      : designer.endpoints
            .map((e) => e.resolve('/api/v1/jobs').toString())
            .join('\n');
  String get diagnostics =>
      '${_esp?.currentStatus.message ?? connectionLabel}\n${designer.currentStatus.message ?? receiverLabel}';

  Future<void> initialize() async {
    try {
      settings = await preferences.load();
      profiles = await calibrations.load();
      if (profiles.isEmpty) {
        final initial = CalibrationProfile(
          id: 'principal',
          name: 'Calibración X',
          referenceX: 0,
          points: [],
        );
        profiles = [initial];
        await calibrations.save(initial);
      }
      // Keep the previously active calibration, not an arbitrary first profile.
      final selected = profiles.firstWhere(
        (p) => p.id == settings.activeProfileId,
        orElse: () => profiles.first,
      );
      profiles = [selected.copyWith(name: 'Calibración X')];
      await calibrations.replaceWith(profile);
      settings = settings.copyWith(activeProfileId: profile.id);
      await preferences.save(settings);
      final session = await store.getString('microfantasy.session.v1');
      if (session == null) {
        progress = JobProgress(CuttingJob.demo());
        await _saveSession();
      } else {
        final data = jsonDecode(session) as Map<String, dynamic>;
        progress = data['job'] == null
            ? null
            : JobProgress(
                CuttingJob.fromJson(Map<String, Object?>.from(data['job'])),
                data['index'] as int? ?? 0,
              );
        // Calibration always opens at its zero reference; cut progress resumes.
        calibrationIndex = 0;
        helperDirection = data['helperDirection'] == 'vertical'
            ? 'vertical'
            : 'horizontal';
        helperZeroView = data['helperZeroView'] == true;
      }
      final pending = await store.getString('microfantasy.pending.v1');
      if (pending != null) pendingJob = jobs.importJson(pending);
    } catch (e) {
      message('No se pudo recuperar parte de la sesión: $e');
      if (profiles.isEmpty) {
        profiles = [
          CalibrationProfile(
            id: 'principal',
            name: 'Calibración X',
            referenceX: 0,
            points: [],
          ),
        ];
      }
    }
    _subscriptions.add(
      designer.pendingJobs.listen((j) => unawaited(receiveJob(j))),
    );
    _subscriptions.add(designer.statusStream.listen((_) => _refresh()));
    _subscriptions.add(discovery.errorStream.listen(message));
    _subscriptions.add(
      discovery.devicesStream.listen((devices) {
        if (devices.isNotEmpty) {
          final device = devices.first;
          unawaited(
            updateSettings(
              settings.copyWith(
                host: device.host,
                port: device.port,
                simulation: false,
              ),
            ),
          );
          message('Máquina encontrada: ${device.name}');
          unawaited(discovery.stop());
        }
      }),
    );
    await ensureReceiver();
    await _run(_connect);
    if (!settings.simulation && !(_esp?.currentStatus.isConnected ?? false)) {
      unawaited(discoverMachine());
    }
    _freshness = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _refresh(),
    );
    ready = true;
    _refresh();
    unawaited(updates.initialize());
  }

  Future<void> _connect() async {
    _connecting++;
    busy = true;
    _refresh();
    final connection = _connections.then((_) async {
      if (!_disposed) await _performConnect();
    });
    // A failed attempt must not poison later reconnect requests.
    _connections = connection.catchError((Object _) {});
    try {
      await connection;
    } finally {
      busy = --_connecting > 0;
      _refresh();
    }
  }

  Future<void> _performConnect() async {
    await _positionSub?.cancel();
    await _statusSub?.cancel();
    await _esp?.dispose();
    if (_disposed) return;
    rawX = null;
    _lastPosition = null;
    final esp = settings.simulation
        ? MockEsp32Service(initialPositionMm: 1.5)
        : WebSocketEsp32Service(
            connectTimeout: settings.timeout,
            telemetryTimeout: settings.timeout,
          );
    _esp = esp;
    _positionSub = esp.positionStream.listen((p) {
      rawX = p.xMm;
      _lastPosition = p.receivedAt;
      final arrived =
          actualX != null &&
          step != null &&
          (actualX! - correctedTarget).abs() <= settings.tolerance;
      if (arrived && !_arrived && settings.haptics) {
        unawaited(HapticFeedback.selectionClick());
      }
      _arrived = arrived;
      _refresh();
    });
    _statusSub = esp.statusStream.listen((s) {
      if (!s.isConnected) _lastPosition = null;
      _refresh();
    });
    await esp.connect(
      Uri(scheme: 'ws', host: settings.host, port: settings.port, path: '/ws'),
    );
    if (esp is MockEsp32Service) esp.startSimulation(minMm: 1.5, maxMm: 2.5);
  }

  Future<void> updateSettings(AppSettings next) async {
    final reconnect =
        next.simulation != settings.simulation ||
        next.host != settings.host ||
        next.port != settings.port ||
        next.timeout != settings.timeout;
    if (next.invertX != settings.invertX) {
      // Stored measurements use the displayed axis direction; transform the profile with it.
      profiles = profiles
          .map(
            (p) => p.copyWith(
              referenceX: -p.referenceX,
              points: p.points
                  .map((q) => CalibrationPoint(angleR: q.angleR, x: -q.x))
                  .toList(),
            ),
          )
          .toList();
      for (final p in profiles) {
        _queue(() => calibrations.save(p));
      }
    }
    settings = next;
    calibrationIndex = calibrationIndex.clamp(0, angles.length - 1);
    _queue(() => preferences.save(next));
    _refresh();
    if (reconnect) {
      await _run(_connect);
      if (!settings.simulation && !(_esp?.currentStatus.isConnected ?? false)) {
        unawaited(discoverMachine());
      }
    }
  }

  void nextStep() {
    progress?.next();
    helperZeroView = false;
    _persistProgress();
  }

  void previousStep() {
    progress?.previous();
    helperZeroView = false;
    _persistProgress();
  }

  void nextAngle() {
    if (!hasCalibrationReference) return;
    calibrationIndex = (calibrationIndex + 1) % angles.length;
    _persistProgress();
  }

  void previousAngle() {
    if (!hasCalibrationReference) return;
    calibrationIndex = (calibrationIndex - 1 + angles.length) % angles.length;
    _persistProgress();
  }

  void _persistProgress() {
    _arrived = false;
    _queue(_saveSession);
    _refresh();
  }

  void setHelperDirection(String value) {
    if (!['horizontal', 'vertical'].contains(value)) return;
    helperDirection = value;
    _persistProgress();
  }

  void setHelperZero(bool value) {
    helperZeroView = value;
    _persistProgress();
  }

  Future<void> _saveSession() => store.setString(
    'microfantasy.session.v1',
    jsonEncode({
      'job': job?.toJson(),
      'index': stepIndex,
      'calibrationIndex': calibrationIndex,
      'helperDirection': helperDirection,
      'helperZeroView': helperZeroView,
    }),
  );
  void _queue(Future<void> Function() write) {
    _writes = _writes.then((_) => write()).catchError((Object e) {
      message('No se pudo guardar: $e');
    });
  }

  Future<void> flush() => _writes;
  Future<void> receiveJob(CuttingJob incoming) async {
    final receipt = _receipts.then(
      (_) => _run(() async {
        await jobs.save(incoming);
        await store.setString(
          'microfantasy.pending.v1',
          jobs.exportJson(incoming),
        );
        // Older proposals remain in the job archive, but only the latest is offered.
        if (pendingJob != null) designer.acknowledgePendingJob(pendingJob!);
        pendingJob = incoming;
        message('Nuevo patrón recibido desde V90 Fantasy Designer');
      }),
    );
    _receipts = receipt;
    await receipt;
  }

  void acceptPending({bool replace = false}) {
    final incoming = pendingJob;
    if (incoming == null) return;
    final previous = job;
    if (replace && previous != null && previous.id != incoming.id) {
      _queue(() => jobs.delete(previous.id));
    }
    progress = JobProgress(incoming, incoming.cutHelper?.initialStepIndex ?? 0);
    helperDirection = incoming.cutHelper?.direction ?? 'horizontal';
    helperZeroView = incoming.cutHelper?.orientation == 'zero';
    pendingJob = null;
    designer.acknowledgePendingJob(incoming);
    _queue(() => store.remove('microfantasy.pending.v1'));
    _persistProgress();
  }

  Future<void> importJob() => _run(() async {
    final text = await files.readJson();
    if (text != null) await receiveJob(jobs.importJson(text));
  });
  void loadDemo() {
    progress = JobProgress(CuttingJob.demo());
    _persistProgress();
    message('Patrón de ejemplo abierto');
  }

  void clearJob() {
    progress = null;
    _persistProgress();
  }

  void _saveProfile(CalibrationProfile p, {double? savedAngle}) {
    profiles = [p];
    final revision = ++_calibrationRevision;
    _queue(() async {
      await calibrations.replaceWith(p);
      if (!_disposed &&
          revision == _calibrationRevision &&
          savedAngle != null) {
        lastSavedCalibrationAngle = savedAngle;
        calibrationSavedId++;
        _refresh();
      }
    });
    _refresh();
  }

  void saveCalibrationPoint() {
    final x = actualX;
    if (x == null) return;
    if (!hasCalibrationReference && calibrationAngle != 0) {
      calibrationIndex = 0;
      _refresh();
      return;
    }
    final angle = calibrationAngle;
    final p = angle == 0 ? profile.copyWith(referenceX: x) : profile;
    _saveProfile(
      p.withPoint(CalibrationPoint(angleR: angle, x: x)),
      savedAngle: angle,
    );
    if (settings.autoAdvance) nextAngle();
  }

  void removeCalibrationPoint() {
    if (calibrationAngle == 0) {
      resetCalibration();
    } else {
      _saveProfile(profile.withoutPoint(calibrationAngle));
    }
  }

  void resetCalibration() {
    calibrationIndex = 0;
    lastSavedCalibrationAngle = null;
    _saveProfile(profile.copyWith(referenceX: 0, points: []));
    _persistProgress();
  }

  Future<void> exportCalibrations() => _run(() async {
    if (await files.saveJson(
      'microfantasy-calibracion.json',
      jsonEncode({'version': 2, 'calibration': profile.toJson()}),
    )) {
      message('Calibración exportada');
    }
  });
  Future<void> importCalibrations() => _run(() async {
    final text = await files.readJson();
    if (text == null) return;
    final data = jsonDecode(text) as Map<String, dynamic>;
    final CalibrationProfile imported;
    if (data['version'] == 2) {
      imported = CalibrationProfile.fromJson(
        Map<String, Object?>.from(data['calibration'] as Map),
      );
    } else if (data['version'] == 1) {
      final old = (data['profiles'] as List)
          .map((p) => CalibrationProfile.fromJson(Map<String, Object?>.from(p)))
          .toList();
      if (old.isEmpty) throw const FormatException('No hay mediciones');
      imported = old.firstWhere(
        (p) => p.id == profile.id,
        orElse: () => old.first,
      );
    } else {
      throw const FormatException('Versión de calibración desconocida');
    }
    // Imported measurements replace this one calibration, never add a profile.
    final next = CalibrationProfile(
      id: profile.id,
      name: 'Calibración X',
      referenceX: imported.referenceX,
      points: imported.points,
    );
    await flush();
    await calibrations.replaceWith(next);
    _calibrationRevision++;
    profiles = [next];
    calibrationIndex = 0;
    lastSavedCalibrationAngle = null;
    _persistProgress();
    message('Calibración importada');
  });

  /// Listening is automatic in the foreground; mobile OS background limits
  /// are respected. Serialize resume/start/stop to avoid competing HTTP binds.
  Future<void> ensureReceiver() {
    final request = _receiverLifecycle.then((_) async {
      if (!_disposed && _foreground && receiverSupported) {
        await designer.setForeground(true);
        if (!_disposed && _foreground) await designer.start();
      }
    });
    _receiverLifecycle = request.catchError((Object e) {
      if (!_disposed) message('No se pudo activar la recepción Wi-Fi: $e');
    });
    return _receiverLifecycle;
  }

  Future<void> foreground(bool value) {
    _foreground = value;
    final request = _receiverLifecycle.then((_) async {
      if (_disposed) return;
      if (!value) await discovery.stop();
      await designer.setForeground(value);
      if (value && !_disposed && _foreground && receiverSupported) {
        await designer.start();
      }
    });
    _receiverLifecycle = request.catchError((Object e) {
      if (!_disposed) message('No se pudo actualizar la recepción Wi-Fi: $e');
    });
    return _receiverLifecycle;
  }

  Future<void> discoverMachine() => _run(() async {
    if (settings.simulation) {
      message('Máquina simulada disponible');
      return;
    }
    message('Buscando en la red local…');
    await discovery.start();
  });
  Future<void> testConnection() => _run(() async {
    await _connect();
    message(
      _esp!.currentStatus.isConnected
          ? 'Conexión establecida'
          : 'Esperando conexión con la máquina',
    );
  });
  void simulateX(double value) {
    final esp = _esp;
    if (esp is MockEsp32Service) esp.setPosition(value);
  }

  void animateSimulation() {
    final esp = _esp;
    final center = correctedTarget * (settings.invertX ? -1 : 1);
    if (esp is MockEsp32Service) {
      esp.startSimulation(minMm: center - 1, maxMm: center + 1);
    }
  }

  void changeHost(String v) => _edit(() => settings.copyWith(host: v));
  void changePort(String v) =>
      _edit(() => settings.copyWith(port: int.parse(v)));
  void changeTimeout(String v) =>
      _edit(() => settings.copyWith(timeoutSeconds: int.parse(v)));
  void changeInterval(String v) =>
      _edit(() => settings.copyWith(angleInterval: int.parse(v)));
  void changeTolerance(String v) => _edit(() {
    final n = double.parse(v.replaceAll(',', '.'));
    if (!n.isFinite || n <= 0) {
      throw const FormatException('Usa una tolerancia mayor que cero');
    }
    return settings.copyWith(tolerance: n);
  });
  void _edit(AppSettings Function() edit) {
    try {
      unawaited(updateSettings(edit()));
    } catch (e) {
      message('Valor no válido: $e');
    }
  }

  void resetSettings() => unawaited(updateSettings(AppSettings()));
  String length(double mm, {bool signed = false}) =>
      '${signed && mm > 0 ? '+' : ''}${settings.units.fromMillimetres(mm).toStringAsFixed(settings.units == LengthUnit.mm ? 3 : 4)} ${settings.units.name}';
  void message(String text) {
    notice = text;
    noticeId++;
    _refresh();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      message('No se pudo completar la acción: $e');
    }
    _refresh();
  }

  void _refresh() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _freshness?.cancel();
    unawaited(_positionSub?.cancel());
    unawaited(_statusSub?.cancel());
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    unawaited(_esp?.dispose());
    unawaited(discovery.dispose());
    unawaited(designer.dispose());
    updates.dispose();
    super.dispose();
  }
}
