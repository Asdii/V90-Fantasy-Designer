import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../repositories/key_value_store.dart';
import '../services/updates/app_update_service.dart';

class UpdateController extends ChangeNotifier {
  UpdateController(this.store, this.service, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final KeyValueStore store;
  final AppUpdateService service;
  final DateTime Function() _now;
  static const _key = 'microfantasy.updates.v1';
  bool automatic = true,
      checking = false,
      opening = false,
      dismissed = false,
      _disposed = false;
  bool _initialized = false;
  DateTime? _lastAttempt;
  InstalledApp? installed;
  AppRelease? available;
  String status = 'Busca nuevas versiones sin interrumpir tu trabajo.';
  Future<void> _writes = Future.value();
  bool get supported => service.supported;
  bool get showBanner => available != null && !dismissed;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (!supported) return;
    try {
      final saved = await store.getString(_key);
      if (saved != null) {
        final data = jsonDecode(saved) as Map<String, dynamic>;
        automatic = data['automatic'] != false;
        _lastAttempt = DateTime.tryParse(data['lastAttempt'] as String? ?? '');
        if (data['available'] != null) {
          available = AppRelease.fromJson(
            data['available'] as Map<String, dynamic>,
          );
        }
      }
    } catch (_) {
      available = null;
    }
    await check();
  }

  Future<void> check({bool manual = false}) async {
    if (!supported || checking || _disposed) return;
    checking = true;
    _refresh();
    try {
      installed ??= await service.installedApp();
      _validateCandidate();
      if (available != null) status = 'Disponible: ${available!.versionName}';
      final elapsed = _lastAttempt == null
          ? null
          : _now().difference(_lastAttempt!);
      if (!manual &&
          (!automatic ||
              (elapsed != null &&
                  !elapsed.isNegative &&
                  elapsed < const Duration(days: 1)))) {
        return;
      }
      _lastAttempt = _now();
      if (manual) status = 'Buscando actualizaciones…';
      _refresh();
      final release = await service.latestRelease();
      if (_disposed) return;
      available = release;
      final compatible = _validateCandidate();
      dismissed = false;
      if (available != null) {
        status = 'Disponible: ${available!.versionName}';
      } else if (release == null) {
        status = 'Aún no hay una actualización publicada.';
      } else if (compatible) {
        status = 'Tienes la última versión.';
      }
    } catch (_) {
      if (manual) {
        status = 'No se pudo comprobar. Revisa internet e inténtalo de nuevo.';
      }
    } finally {
      checking = false;
      if (!_disposed) {
        await _save();
        _refresh();
      }
    }
  }

  bool _validateCandidate() {
    final candidate = available, current = installed;
    if (candidate == null || current == null) return true;
    if (candidate.versionCode <= current.versionCode) {
      available = null;
      return true;
    }
    if (candidate.applicationId != current.applicationId ||
        candidate.certificateSha256 !=
            current.certificateSha256.toLowerCase()) {
      available = null;
      status =
          'La versión publicada usa otra firma. Conserva tu instalación y revisa la configuración de publicación.';
      return false;
    }
    return true;
  }

  Future<void> setAutomatic(bool value) async {
    automatic = value;
    await _save();
    _refresh();
    if (value) await check();
  }

  void later() {
    dismissed = true;
    _refresh();
  }

  Future<void> download() async {
    final release = available;
    if (release == null || opening || _disposed) return;
    opening = true;
    _refresh();
    try {
      await service.openDownload(release);
      status =
          'Descarga el APK, ábrelo y confirma Actualizar en Android. No desinstales la app: así conservas tus datos.';
    } catch (_) {
      status = 'No se pudo abrir la descarga. Inténtalo de nuevo.';
    } finally {
      opening = false;
      _refresh();
    }
  }

  Future<void> _save() {
    final json = jsonEncode({
      'automatic': automatic,
      'lastAttempt': _lastAttempt?.toIso8601String(),
      'available': available?.toJson(),
    });
    _writes = _writes
        .catchError((Object _) {})
        .then((_) => store.setString(_key, json));
    // An unavailable preferences store must never interrupt cutting/navigation.
    return _writes.catchError((Object _) {});
  }

  Future<void> flush() => _writes.catchError((Object _) {});
  void _refresh() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
