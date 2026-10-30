import 'dart:async';
import 'dart:convert';
import '../../models/fantasy_job.dart';
import 'fantasy_designer_service.dart';
import 'receiver_protocol.dart';

/// Shared queue/validation behavior for native and browser simulation receivers.
abstract class ReceiverCore implements FantasyDesignerService {
  ReceiverCore({this.maxBodyBytes = 1024 * 1024, this.maxPendingJobs = 10}) {
    if (maxBodyBytes <= 0 || maxPendingJobs <= 0) {
      throw ArgumentError('Body and queue limits must be positive');
    }
  }
  final int maxBodyBytes;
  final int maxPendingJobs;
  final _jobs = StreamController<FantasyJob>.broadcast();
  final _statuses = StreamController<ReceiverStatus>.broadcast();
  final _queue = <FantasyJob>[];
  ReceiverStatus _status = const ReceiverStatus(
    state: ReceiverState.stopped,
    isForeground: true,
  );
  bool isDisposed = false;
  bool isForeground = true;

  @override
  Stream<FantasyJob> get pendingJobs => _jobs.stream;
  @override
  List<FantasyJob> get pendingQueue => List.unmodifiable(_queue);
  @override
  Stream<ReceiverStatus> get statusStream => _statuses.stream;
  @override
  ReceiverStatus get currentStatus => _status;
  @override
  List<Uri> get endpoints => _status.endpoints;

  void checkCanStart() {
    if (isDisposed) throw StateError('Receiver is disposed');
    if (!isForeground) {
      throw StateError('Receiver is only available in the foreground');
    }
  }

  void publishStatus(
    ReceiverState state, {
    int? port,
    String? message,
    List<Uri> endpoints = const [],
  }) {
    if (isDisposed) return;
    _status = ReceiverStatus(
      state: state,
      isForeground: isForeground,
      port: port,
      message: message,
      pendingCount: _queue.length,
      endpoints: List.unmodifiable(endpoints),
    );
    _statuses.add(_status);
  }

  void queuePendingJob(FantasyJob job) {
    if (isDisposed || !isForeground || !currentStatus.isRunning) {
      throw const ReceiverProtocolException(
        503,
        'receiver_inactive',
        'Enable the receiver in the foreground',
      );
    }
    if (_queue.length >= maxPendingJobs) {
      throw const ReceiverProtocolException(
        429,
        'pending_queue_full',
        'Review pending jobs before sending another',
      );
    }
    _queue.add(job);
    _jobs.add(job);
    publishStatus(
      _status.state,
      port: _status.port,
      message: _status.message,
      endpoints: _status.endpoints,
    );
  }

  /// Local UI-only simulation; uses the same model validation and bounded queue.
  void simulateIncomingJob(Map<String, dynamic> json) {
    queuePendingJob(
      decodeReceivedJob(
        utf8.encode(jsonEncode(json)),
        maxBodyBytes: maxBodyBytes,
      ),
    );
  }

  @override
  void acknowledgePendingJob(FantasyJob job) {
    if (isDisposed) return;
    final index = _queue.indexWhere((candidate) => identical(candidate, job));
    if (index < 0) return;
    _queue.removeAt(index);
    publishStatus(
      _status.state,
      port: _status.port,
      message: _status.message,
      endpoints: _status.endpoints,
    );
  }

  @override
  Future<void> setForeground(bool foreground) async {
    if (isDisposed) return;
    isForeground = foreground;
    if (!foreground) {
      await stop();
    } else {
      publishStatus(
        _status.state,
        port: _status.port,
        message: _status.message,
        endpoints: _status.endpoints,
      );
    }
  }

  @override
  Future<void> dispose() async {
    if (isDisposed) return;
    await stop();
    isDisposed = true;
    _queue.clear();
    await Future.wait([_jobs.close(), _statuses.close()]);
  }
}
