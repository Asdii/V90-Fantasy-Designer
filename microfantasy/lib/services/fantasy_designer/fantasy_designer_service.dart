import '../../models/fantasy_job.dart';

/// Incoming jobs are pending proposals. The controller chooses when to apply one.
abstract interface class FantasyDesignerService {
  Stream<FantasyJob> get pendingJobs;
  List<FantasyJob> get pendingQueue;
  Stream<ReceiverStatus> get statusStream;
  ReceiverStatus get currentStatus;

  /// Actual listening addresses for this session; empty when stopped or on web.
  List<Uri> get endpoints;
  bool get supportsNativeReceiver;
  Future<void> start();
  Future<void> stop();

  /// Call from the app lifecycle; leaving foreground stops the receiver.
  Future<void> setForeground(bool foreground);
  void acknowledgePendingJob(FantasyJob job);
  Future<void> dispose();
}

enum ReceiverState { stopped, starting, listening, simulation, error }

class ReceiverStatus {
  const ReceiverStatus({
    required this.state,
    required this.isForeground,
    this.port,
    this.pendingCount = 0,
    this.message,
    this.endpoints = const [],
  });
  final ReceiverState state;
  final bool isForeground;
  final int? port;
  final int pendingCount;
  final String? message;
  final List<Uri> endpoints;
  bool get isRunning =>
      state == ReceiverState.listening || state == ReceiverState.simulation;
}
