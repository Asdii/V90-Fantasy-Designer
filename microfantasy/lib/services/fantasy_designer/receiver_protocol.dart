import 'dart:async';
import 'dart:convert';
import '../../models/fantasy_job.dart';

class ReceiverProtocolException implements Exception {
  const ReceiverProtocolException(this.statusCode, this.code, this.message);
  final int statusCode;
  final String code;
  final String message;
  Map<String, Object> toJson() => {
    'error': {'code': code, 'message': message},
  };
  @override
  String toString() => 'ReceiverProtocolException($code): $message';
}

FantasyJob decodeReceivedJob(
  List<int> bytes, {
  int maxBodyBytes = 1024 * 1024,
}) {
  if (bytes.length > maxBodyBytes) {
    throw const ReceiverProtocolException(
      413,
      'body_too_large',
      'Job exceeds the request size limit',
    );
  }
  final Object? json;
  try {
    json = jsonDecode(utf8.decode(bytes));
  } on FormatException {
    throw const ReceiverProtocolException(
      400,
      'invalid_json',
      'Expected valid UTF-8 JSON',
    );
  }
  if (json is! Map<String, dynamic>) {
    throw const ReceiverProtocolException(
      400,
      'invalid_job',
      'Job must be a JSON object',
    );
  }
  try {
    return FantasyJob.fromJson(json);
  } on FormatException catch (error) {
    // Model errors are bounded; never reflect a whole submitted document.
    final message = error.message.toString();
    throw ReceiverProtocolException(
      400,
      'invalid_job',
      message.length <= 240 ? message : '${message.substring(0, 240)}...',
    );
  } on ArgumentError {
    throw const ReceiverProtocolException(
      400,
      'invalid_job',
      'Job fields failed validation',
    );
  } on TypeError {
    throw const ReceiverProtocolException(
      400,
      'invalid_job',
      'Job fields have incorrect types',
    );
  }
}

/// Bounded streaming read with a total deadline (not just an inactivity timer).
Future<List<int>> readReceiverBody(
  Stream<List<int>> source, {
  required int maxBytes,
  required Duration timeout,
  void Function(Future<void> Function() cancel)? deferCancel,
}) {
  final result = Completer<List<int>>();
  final bytes = <int>[];
  StreamSubscription<List<int>>? subscription;
  Timer? timer;
  void fail(Object error, [StackTrace? stack]) {
    if (result.isCompleted) return;
    result.completeError(error, stack);
    timer?.cancel();
    final active = subscription;
    if (active != null) {
      if (deferCancel != null) {
        // HttpRequest cancellation can close the socket. Give the server a
        // chance to flush its JSON error before releasing the failed upload.
        active.pause();
        deferCancel(active.cancel);
      } else {
        unawaited(active.cancel());
      }
    }
  }

  timer = Timer(
    timeout,
    () => fail(
      const ReceiverProtocolException(
        408,
        'body_timeout',
        'Request body did not complete in time',
      ),
    ),
  );
  subscription = source.listen(
    (chunk) {
      if (result.isCompleted) return;
      if (bytes.length + chunk.length > maxBytes) {
        fail(
          const ReceiverProtocolException(
            413,
            'body_too_large',
            'Job exceeds the request size limit',
          ),
        );
      } else {
        bytes.addAll(chunk);
      }
    },
    onError: (Object error, StackTrace stack) {
      fail(
        const ReceiverProtocolException(
          400,
          'body_read_failed',
          'Could not read request body',
        ),
        stack,
      );
    },
    onDone: () {
      if (!result.isCompleted) {
        timer?.cancel();
        result.complete(bytes);
      }
    },
    cancelOnError: true,
  );
  return result.future;
}

bool pairingTokensEqual(String? expected, String? supplied) {
  if (expected == null ||
      supplied == null ||
      expected.length != supplied.length) {
    return false;
  }
  var difference = 0;
  for (var i = 0; i < expected.length; i++) {
    difference |= expected.codeUnitAt(i) ^ supplied.codeUnitAt(i);
  }
  return difference == 0;
}
