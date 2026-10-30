import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'fantasy_designer_service.dart';
import 'receiver_core.dart';
import 'receiver_protocol.dart';

class LocalReceiverService extends ReceiverCore {
  LocalReceiverService({
    this.port = 8787,
    this.bindAddress = '0.0.0.0',
    super.maxBodyBytes,
    super.maxPendingJobs,
    this.bodyTimeout = const Duration(seconds: 10),
    Set<String> allowedOrigins = const {},
    this.allowBrowserAccess = false,
  }) : allowedOrigins = Set.unmodifiable(allowedOrigins) {
    if (port < 0 || port > 65535) throw ArgumentError.value(port, 'port');
    if (bodyTimeout <= Duration.zero) {
      throw ArgumentError('bodyTimeout must be positive');
    }
    if (allowedOrigins.contains('*') || allowedOrigins.contains('null')) {
      throw ArgumentError('CORS requires explicit trusted origins');
    }
  }
  final int port;
  final String bindAddress;
  final Duration bodyTimeout;
  final Set<String> allowedOrigins;
  final bool allowBrowserAccess;
  HttpServer? _server;
  Future<void>? _starting;
  int _generation = 0;

  @override
  bool get supportsNativeReceiver => true;

  @override
  Future<void> start() {
    checkCanStart();
    if (currentStatus.state == ReceiverState.starting) return _starting!;
    if (currentStatus.isRunning) return Future.value();
    return _starting = _start();
  }

  Future<void> _start() async {
    final generation = ++_generation;
    publishStatus(ReceiverState.starting);
    try {
      final server = await HttpServer.bind(bindAddress, port, shared: false);
      final addresses = await _listEndpoints(server);
      if (isDisposed || !isForeground || generation != _generation) {
        await server.close(force: true);
        return;
      }
      _server = server;
      server.idleTimeout = bodyTimeout;
      server.autoCompress = false;
      publishStatus(
        ReceiverState.listening,
        port: server.port,
        endpoints: addresses,
        message: addresses.isEmpty
            ? 'Listening; LAN addresses are unavailable'
            : null,
      );
      server.listen(
        (request) => unawaited(_handle(request, generation)),
        onError: (Object error) {
          if (generation == _generation && !isDisposed) {
            unawaited(stop());
            publishStatus(
              ReceiverState.error,
              message: 'Receiver connection failed',
            );
          }
        },
      );
    } catch (_) {
      if (generation == _generation && !isDisposed) {
        publishStatus(
          ReceiverState.error,
          message: 'Could not open the receiver port',
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    _starting = null;
    final server = _server;
    _server = null;
    publishStatus(ReceiverState.stopped);
    if (server != null) await server.close(force: true);
  }

  bool _active(int generation) =>
      generation == _generation &&
      !isDisposed &&
      isForeground &&
      currentStatus.state == ReceiverState.listening;

  Future<List<Uri>> _listEndpoints(HttpServer server) async {
    final bound = server.address;
    if (bound.address != '0.0.0.0' && bound.address != '::') {
      return [Uri(scheme: 'http', host: bound.address, port: server.port)];
    }
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
        type: bound.type,
      );
      final addresses =
          interfaces
              .expand((item) => item.addresses)
              .map(
                (address) => Uri(
                  scheme: 'http',
                  host: address.address,
                  port: server.port,
                ),
              )
              .toSet()
              .toList()
            ..sort((a, b) => a.toString().compareTo(b.toString()));
      return addresses;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _handle(HttpRequest request, int generation) async {
    Future<void> Function()? cancelBody;
    final response = request.response;
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.headers.set('X-Content-Type-Options', 'nosniff');
    // Avoid retaining slow/rejected request bodies on keepalive connections.
    response.persistentConnection = false;
    try {
      if (!_active(generation)) {
        throw const ReceiverProtocolException(
          503,
          'receiver_inactive',
          'Receiver is not active',
        );
      }
      final origin = request.headers.value('origin');
      if (origin != null) {
        final parsed = Uri.tryParse(origin);
        final browserCandidate =
            allowBrowserAccess &&
            parsed != null &&
            ['http', 'https'].contains(parsed.scheme) &&
            parsed.host.isNotEmpty &&
            parsed.userInfo.isEmpty &&
            parsed.path.isEmpty &&
            !parsed.hasQuery &&
            !parsed.hasFragment;
        if (!allowedOrigins.contains(origin) && !browserCandidate) {
          throw const ReceiverProtocolException(
            403,
            'origin_not_allowed',
            'Origin is not allowed for this receiver',
          );
        }
        response.headers.set('Access-Control-Allow-Origin', origin);
        response.headers.set('Vary', 'Origin');
      }
      final path = request.uri.path;
      if (path != '/api/v1/jobs' && path != '/api/v1/status') {
        throw const ReceiverProtocolException(
          404,
          'not_found',
          'Unknown API route',
        );
      }
      final allowedMethod = path == '/api/v1/jobs' ? 'POST' : 'GET';
      if (request.method == 'OPTIONS' && origin != null) {
        response.headers.set(
          'Access-Control-Allow-Methods',
          '$allowedMethod, OPTIONS',
        );
        response.headers.set('Access-Control-Allow-Headers', 'Content-Type');
        if (request.headers.value('access-control-request-private-network') ==
            'true') {
          response.headers.set('Access-Control-Allow-Private-Network', 'true');
        }
        response.statusCode = HttpStatus.noContent;
        await response.close();
        return;
      }
      if (request.method != allowedMethod) {
        response.headers.set(HttpHeaders.allowHeader, allowedMethod);
        throw const ReceiverProtocolException(
          405,
          'method_not_allowed',
          'Method is not allowed for this route',
        );
      }
      if (path == '/api/v1/status') {
        await _respond(response, HttpStatus.ok, {
          'service': 'microfantasy',
          'api_version': 1,
          'state': currentStatus.state.name,
          'accepting_jobs': true,
          'pairing_required': false,
          'pending_count': pendingQueue.length,
          'cut_helper_versions': [1],
          'max_job_bytes': maxBodyBytes,
        });
        return;
      }
      final type = request.headers.contentType;
      if (type?.mimeType.toLowerCase() != 'application/json' ||
          (type?.charset != null && type!.charset!.toLowerCase() != 'utf-8') ||
          request.headers.value(HttpHeaders.contentEncodingHeader) != null) {
        throw const ReceiverProtocolException(
          415,
          'unsupported_media_type',
          'Use uncompressed UTF-8 application/json',
        );
      }
      if (request.contentLength > maxBodyBytes) {
        throw const ReceiverProtocolException(
          413,
          'body_too_large',
          'Job exceeds the request size limit',
        );
      }
      if (pendingQueue.length >= maxPendingJobs) {
        throw const ReceiverProtocolException(
          429,
          'pending_queue_full',
          'Review pending jobs before sending another',
        );
      }
      final bytes = await readReceiverBody(
        request,
        maxBytes: maxBodyBytes,
        timeout: bodyTimeout,
        deferCancel: (cancel) => cancelBody = cancel,
      );
      if (!_active(generation)) {
        throw const ReceiverProtocolException(
          503,
          'receiver_inactive',
          'Receiver session ended during upload',
        );
      }
      final job = decodeReceivedJob(bytes, maxBodyBytes: maxBodyBytes);
      queuePendingJob(job); // Does not replace any active job.
      await _respond(response, HttpStatus.accepted, {
        'status': 'pending',
        'pending_count': pendingQueue.length,
        'job_id': job.jobId,
        'cut_helper_version': job.cutHelper == null ? null : 1,
      });
    } on ReceiverProtocolException catch (error) {
      await _respondQuietly(response, error.statusCode, error.toJson());
    } on HttpException {
      await _respondQuietly(
        response,
        400,
        const ReceiverProtocolException(
          400,
          'invalid_headers',
          'Invalid request headers',
        ).toJson(),
      );
    } catch (_) {
      await _respondQuietly(
        response,
        500,
        const ReceiverProtocolException(
          500,
          'internal_error',
          'Request could not be processed',
        ).toJson(),
      );
    } finally {
      if (cancelBody != null) await cancelBody!();
    }
  }

  Future<void> _respond(
    HttpResponse response,
    int status,
    Map<String, Object?> json,
  ) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    final bytes = utf8.encode(jsonEncode(json));
    response.contentLength = bytes.length;
    response.add(bytes);
    await response.close();
  }

  Future<void> _respondQuietly(
    HttpResponse response,
    int status,
    Map<String, Object?> json,
  ) async {
    try {
      await _respond(response, status, json);
    } catch (_) {
      /* Peer disconnected. */
    }
  }
}
