import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../models/job_progress.dart';
import '../models/x_axis_calibration.dart';
import '../repositories/x_axis_repository.dart';
import '../repositories/machine_boot_repository.dart';
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
    this.hardwareFactory,
    FileTransfer? files,
    AppUpdateService updateService = const UnsupportedUpdateService(),
  }) : files = files ?? FileTransfer(),
       updates = UpdateController(store, updateService),
       jobs = JobRepository(store),
       preferences = SettingsRepository(store),
       calibrations = CalibrationRepository(store),
       xAxes = XAxisRepository(store),
       machineBoots = MachineBootRepository(store);
  final KeyValueStore store;
  final FantasyDesignerService designer;
  final Esp32Service Function(AppSettings settings)? hardwareFactory;
  final FileTransfer files;
  final UpdateController updates;
  final JobRepository jobs;
  final SettingsRepository preferences;
  final CalibrationRepository calibrations;
  final XAxisRepository xAxes;
  final MachineBootRepository machineBoots;
  final Map<String, MachineBootRecord> _machineBoots = {};
  Future<void> _bootSync = Future<void>.value();
  bool _handlingBoot = false;
  (String, String)? _lastBootToken;
  DateTime? _lastBootAttempt;
  final Map<String, AxisCalibration> _xAxes = {};
  bool xCalibrationBusy = false;
  String? xCalibrationMessage;
  Esp32Position? _sensorPosition;
  final CalibrationService calibration = const CalibrationService();
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
  double? get sensorX {
    final status = _esp?.currentStatus;
    if (!(_esp?.currentStatus.isConnected ?? false) ||
        rawX == null ||
        _lastPosition == null ||
        (status?.bootId != null &&
            (_sensorPosition?.bootId != status?.bootId ||
                _sensorPosition?.referenceRevision !=
                    status?.referenceRevision ||
                _sensorPosition?.referenceId != status?.referenceId)) ||
        DateTime.now().difference(_lastPosition!) > settings.timeout) {
      return null;
    }
    return rawX! * (settings.invertX ? -1 : 1);
  }

  String? get _axisDeviceId => settings.simulation
      ? 'microfantasy-simulation'
      : _esp?.currentStatus.deviceId ?? settings.machineId;
  AxisCalibration? get xCalibration => _xAxes[_axisDeviceId];
  MachineBootRecord? get pendingBootNotice {
    if (settings.simulation) return null;
    final record = _machineBoots[_axisDeviceId];
    return record?.unread == true ? record : null;
  }

  bool get machineConnected => sensorX != null;
  bool get machineConnecting => _connecting > 0;
  bool get xReferenceSupported =>
      _esp is XReferenceEsp32Service &&
      _esp?.currentStatus.supportsXReference == true;
  bool get xAxisReady {
    final axis = xCalibration;
    final status = _esp?.currentStatus;
    final position = _sensorPosition;
    return axis != null &&
        sensorX != null &&
        status?.bootId != null &&
        status?.referenceId == axis.referenceId &&
        position?.bootId == status?.bootId &&
        position?.referenceId == axis.referenceId &&
        position?.referenceRevision == status?.referenceRevision;
  }

  bool get xNeedsReference =>
      (xCalibration != null || (!settings.simulation && xReferenceSupported)) &&
      !xAxisReady;
  double? get actualX => xCalibrationBusy || xNeedsReference ? null : sensorX;

  String get connectionLabel => settings.simulation
      ? 'Simulación'
      : machineConnected
      ? 'Conectado'
      : _esp?.currentStatus.state == Esp32ConnectionState.reconnecting ||
            _esp?.currentStatus.state == Esp32ConnectionState.connecting
      ? 'Buscando máquina…'
      : 'Desconectado · esperando lectura';
  String get machineAddress => _esp?.currentStatus.isConnected == true
      ? _esp!.currentStatus.endpoint?.host ?? settings.host
      : settings.host;
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
      for (final record in await machineBoots.load()) {
        _machineBoots[record.deviceId] = record;
      }
      for (final axis in await xAxes.load()) {
        _xAxes[axis.deviceId] = axis;
      }
      profiles = await calibrations.load();
      if (profiles.isEmpty) {
        final initial = CalibrationProfile(
          id: 'principal',
          name: 'Calibración R',
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
      profiles = [selected.copyWith(name: 'Calibración R')];
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
            name: 'Calibración R',
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
    await ensureReceiver();
    await _run(_connect);
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
    _esp = null;
    rawX = null;
    _sensorPosition = null;
    _lastPosition = null;
    if (_disposed || (!_foreground && !settings.simulation)) return;
    final esp = settings.simulation
        ? MockEsp32Service(initialPositionMm: 1.5)
        : hardwareFactory?.call(settings) ??
              WebSocketEsp32Service(
                resolver: Esp32Discovery(),
                deviceId: settings.machineId,
                connectTimeout: settings.timeout,
                // Transport recovery tolerates short phone/radio stalls. The
                // sensorX freshness check still hides expired measurements.
                telemetryTimeout: settings.timeout < const Duration(seconds: 10)
                    ? const Duration(seconds: 10)
                    : settings.timeout,
              );
    _esp = esp;
    _positionSub = esp.positionStream.listen((p) {
      _sensorPosition = p;
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
      _receiveBootNotice(esp, s);
      final endpoint = s.endpoint;
      if (!settings.simulation &&
          s.isConnected &&
          endpoint != null &&
          (settings.host != endpoint.host ||
              settings.port != endpoint.port ||
              settings.machineId != s.deviceId)) {
        // Persist only a confirmed peer. Updating its address must not restart
        // the working connection or reset the encoder/calibration.
        settings = settings.copyWith(
          host: endpoint.host,
          port: endpoint.port,
          machineId: s.deviceId,
        );
        final confirmed = settings;
        _queue(() => preferences.save(confirmed));
      }
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
        next.machineId != settings.machineId ||
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
      for (final item in _xAxes.entries.toList()) {
        final inverted = item.value.inverted();
        _xAxes[item.key] = inverted;
        _queue(() => xAxes.save(inverted));
      }
    }
    settings = next;
    calibrationIndex = calibrationIndex.clamp(0, angles.length - 1);
    _queue(() => preferences.save(next));
    _refresh();
    if (reconnect) {
      await _run(_connect);
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

  Future<void> flush() async {
    await _writes;
    await _bootSync;
  }

  void _receiveBootNotice(Esp32Service esp, Esp32Status status) {
    final deviceId = status.deviceId, bootId = status.bootId;
    if (settings.simulation ||
        !status.isConnected ||
        deviceId == null ||
        bootId == null ||
        _disposed ||
        _handlingBoot) {
      return;
    }
    final known = _machineBoots[deviceId];
    final needsReceipt = status.supportsBootNotice && status.bootNoticePending;
    if (known?.bootId == bootId && !needsReceipt) return;
    final token = (deviceId, bootId);
    final now = DateTime.now();
    if (_lastBootToken == token &&
        _lastBootAttempt != null &&
        now.difference(_lastBootAttempt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastBootToken = token;
    _lastBootAttempt = now;
    _handlingBoot = true;
    _bootSync = _bootSync
        .then((_) async {
          final current = _machineBoots[deviceId];
          final record = current?.bootId == bootId
              ? current!
              : MachineBootRecord(deviceId: deviceId, bootId: bootId);
          await machineBoots.save(record);
          _machineBoots[deviceId] = record;
          _refresh();
          // An app receipt means "saved", not "X has been calibrated". Never
          // restore an old sensor reading or acknowledge a different power-on.
          if (_foreground &&
              !_disposed &&
              identical(esp, _esp) &&
              esp.currentStatus.isConnected &&
              esp.currentStatus.bootId == bootId &&
              needsReceipt &&
              esp is BootNoticeEsp32Service) {
            await (esp as BootNoticeEsp32Service).acknowledgeBoot(bootId);
          }
        })
        .catchError((Object error) {
          debugPrint('Boot notice not acknowledged: $error');
          // The board keeps the pending notice and will retry on its next status.
        })
        .whenComplete(() {
          _handlingBoot = false;
        });
  }

  Future<void> dismissBootNotice() {
    final record = pendingBootNotice;
    if (record == null) return Future<void>.value();
    _bootSync = _bootSync
        .then((_) async {
          if (_machineBoots[record.deviceId]?.bootId != record.bootId) return;
          final read = MachineBootRecord(
            deviceId: record.deviceId,
            bootId: record.bootId,
            unread: false,
          );
          await machineBoots.save(read);
          _machineBoots[read.deviceId] = read;
          _refresh();
        })
        .catchError((Object error) {
          debugPrint('Boot notice could not be dismissed: $error');
        });
    return _bootSync;
  }

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
      name: 'Calibración R',
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
    // Repeated resumed/focus events must not replace an active connection or
    // interrupt discovery just because its first position has not arrived yet.
    if (_foreground == value) return _receiverLifecycle;
    _foreground = value;
    final request = _receiverLifecycle.then((_) async {
      if (_disposed || value != _foreground) return;
      if (!value && !settings.simulation) await _esp?.disconnect();
      if (value && _foreground && !settings.simulation && !machineConnected) {
        await _connect();
      }
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
    await reconnectMachine();
  });

  /// A tap bypasses scheduled retry/backoff and performs fresh identity-based
  /// discovery. It never resets the encoder or sends a remembered phone value.
  Future<void> reconnectMachine() async {
    if (machineConnecting || xCalibrationBusy) return;
    await _run(_connect);
  }

  Future<void> _xAction(Future<void> Function() action) async {
    if (xCalibrationBusy) return;
    xCalibrationBusy = true;
    xCalibrationMessage = null;
    _refresh();
    try {
      await action();
    } catch (e) {
      final reason = switch (e) {
        FormatException() => e.message,
        StateError() => e.message,
        TimeoutException() => e.message ?? 'La máquina no respondió.',
        _ => 'Revisa la conexión e inténtalo de nuevo.',
      };
      debugPrint('X reference: $e');
      xCalibrationMessage = 'No se pudo confirmar: $reason';
    } finally {
      xCalibrationBusy = false;
      _arrived = false;
      _refresh();
    }
  }

  XReferenceEsp32Service _referenceService() {
    final esp = _esp;
    if (!machineConnected ||
        !xReferenceSupported ||
        esp is! XReferenceEsp32Service ||
        _esp?.currentStatus.bootId == null) {
      throw StateError('Conecta la máquina con el firmware actualizado.');
    }
    return esp as XReferenceEsp32Service;
  }

  Future<void> captureXCenter() => _xAction(() async {
    final service = _referenceService();
    final deviceId = _axisDeviceId!;
    final bootId = _esp!.currentStatus.bootId!;
    final before = sensorX!;
    final wasReferenced = xCalibration == null || xAxisReady;
    final candidate = AxisCalibration(
      deviceId: deviceId,
      referenceId:
          'x-${DateTime.now().microsecondsSinceEpoch}-${math.Random.secure().nextInt(0x7fffffff)}',
    );
    // Persist the user's intended frame first. If the ACK is lost or the app
    // closes, subsequent telemetry can confirm that exact frame. It never
    // becomes usable merely because the phone saved a number.
    await xAxes.save(candidate);
    _xAxes[deviceId] = candidate;
    if (wasReferenced && hasCalibrationReference) {
      // Translate absolute R samples together; eccentricity offsets stay equal.
      _saveProfile(
        profile.copyWith(
          referenceX: profile.referenceX - before,
          points: profile.points
              .map((p) => CalibrationPoint(angleR: p.angleR, x: p.x - before))
              .toList(),
        ),
      );
    }
    await service.setXReference(
      bootId: bootId,
      referenceId: candidate.referenceId,
      xMm: 0,
    );
    xCalibrationMessage =
        'Centro guardado en 0.000 mm. Registra los dos topes.';
  });

  Future<void> captureXNegative() => _captureXStop(false);
  Future<void> captureXPositive() => _captureXStop(true);
  Future<void> _captureXStop(bool positive) => _xAction(() async {
    if (!xAxisReady) {
      throw StateError(
        'Establece el centro o recupera un tope antes de medir.',
      );
    }
    final axis = xCalibration!;
    final next = axis.withStop(positive: positive, value: sensorX!);
    await xAxes.save(next);
    _xAxes[axis.deviceId] = next;
    xCalibrationMessage = next.isComplete
        ? 'Recorrido guardado. El centro físico está listo.'
        : 'Tope ${positive ? '−' : '+'} guardado. Registra el otro extremo.';
  });

  Future<void> referenceXAtStop({required bool positive}) => _xAction(() async {
    final service = _referenceService();
    final axis = xCalibration;
    final coordinate = positive ? axis?.positiveMm : axis?.negativeMm;
    if (axis == null || coordinate == null) {
      throw StateError('Este tope aún no tiene una distancia guardada.');
    }
    await service.setXReference(
      bootId: _esp!.currentStatus.bootId!,
      referenceId: axis.referenceId,
      xMm: coordinate * (settings.invertX ? -1 : 1),
    );
    xCalibrationMessage =
        'Tope confirmado. Mueve X hasta 0.000 mm para volver al centro.';
  });

  Future<void> resetXCalibration() => _xAction(() async {
    final id = _axisDeviceId;
    if (id == null) return;
    await xAxes.delete(id);
    _xAxes.remove(id);
    xCalibrationMessage =
        'Recorrido borrado. Sitúa la mesa en su centro para empezar.';
  });
  Future<void> testConnection() => _run(() async {
    await _connect();
    message(
      _esp?.currentStatus.isConnected == true
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

  void changeHost(String v) =>
      _edit(() => settings.copyWith(host: v, clearMachineId: true));
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
    unawaited(designer.dispose());
    updates.dispose();
    super.dispose();
  }
}
