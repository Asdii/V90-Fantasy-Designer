import 'fantasy_designer_service.dart';
import 'receiver_core.dart';

/// No dart:io or nsd dependency reaches a browser build through this export.
class LocalReceiverService extends ReceiverCore {
  LocalReceiverService({
    this.port = 8787,
    this.bindAddress = '0.0.0.0',
    super.maxBodyBytes,
    super.maxPendingJobs,
    this.bodyTimeout = const Duration(seconds: 10),
    Set<String> allowedOrigins = const {},
    this.allowBrowserPairing = false,
  }) : allowedOrigins = Set.unmodifiable(allowedOrigins);
  final int port;
  final String bindAddress;
  final Duration bodyTimeout;
  final Set<String> allowedOrigins;
  final bool allowBrowserPairing;
  @override
  bool get supportsNativeReceiver => false;
  @override
  Future<void> start() async {
    checkCanStart();
    publishStatus(
      ReceiverState.simulation,
      message: 'Web preview: simulated incoming jobs only; no LAN receiver',
    );
  }

  @override
  Future<void> stop() async {
    endPairingSession();
    publishStatus(ReceiverState.stopped);
  }
}
