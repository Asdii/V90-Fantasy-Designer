import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/services/fantasy_designer/local_receiver_service.dart';
import 'package:microfantasy/services/fantasy_designer/local_receiver_service_stub.dart'
    as preview;
import 'package:microfantasy/services/fantasy_designer/receiver_protocol.dart';

Map<String, dynamic> jobJson([String id = 'test-job']) => {
  'jobId': id,
  'units': 'mm',
  'name': 'Test job',
  'steps': [
    {'index': 1, 'angleR': 0, 'x': 1.25, 'depth': 0.1},
  ],
};

void main() {
  test(
    'slow native upload receives JSON timeout before socket closes',
    () async {
      final receiver = LocalReceiverService(
        port: 0,
        bindAddress: '127.0.0.1',
        bodyTimeout: const Duration(milliseconds: 100),
      );
      addTearDown(receiver.dispose);
      await receiver.start();
      final socket = await Socket.connect(
        '127.0.0.1',
        receiver.currentStatus.port!,
      );
      addTearDown(socket.destroy);
      final response = utf8.decoder.bind(socket).join();
      socket.write(
        'POST /api/v1/jobs HTTP/1.1\r\n'
        'Host: localhost\r\nContent-Type: application/json\r\n'
        'Authorization: Bearer ${receiver.pairingToken}\r\n'
        'Content-Length: 100\r\n\r\n{',
      );
      await socket.flush();
      final text = await response.timeout(const Duration(seconds: 3));
      expect(text, contains('408'));
      expect(text, contains('"code":"body_timeout"'));
      expect(receiver.pendingQueue, isEmpty);
    },
  );

  test('protocol validates JSON shape, model fields, UTF-8 and size', () {
    expect(
      decodeReceivedJob(utf8.encode(jsonEncode(jobJson()))).toJson()['jobId'],
      'test-job',
    );
    for (final bytes in [
      utf8.encode('[]'),
      utf8.encode('{}'),
      [255],
      utf8.encode('{'),
    ]) {
      expect(
        () => decodeReceivedJob(bytes),
        throwsA(isA<ReceiverProtocolException>()),
      );
    }
    expect(
      () => decodeReceivedJob(
        utf8.encode(jsonEncode(jobJson())),
        maxBodyBytes: 2,
      ),
      throwsA(
        isA<ReceiverProtocolException>().having(
          (e) => e.statusCode,
          'status',
          413,
        ),
      ),
    );
  });

  test('streamed size limit cancels chunked input', () async {
    final input = StreamController<List<int>>();
    final body = readReceiverBody(
      input.stream,
      maxBytes: 3,
      timeout: const Duration(seconds: 1),
    );
    final check = expectLater(
      body,
      throwsA(
        isA<ReceiverProtocolException>().having(
          (e) => e.statusCode,
          'status',
          413,
        ),
      ),
    );
    input.add([1, 2]);
    input.add([3, 4]);
    await check;
    await input.close();
  });

  test('body timeout is absolute even when chunks keep arriving', () async {
    final input = StreamController<List<int>>();
    final timer = Timer.periodic(
      const Duration(milliseconds: 5),
      (_) => input.add([32]),
    );
    final body = readReceiverBody(
      input.stream,
      maxBytes: 10000,
      timeout: const Duration(milliseconds: 40),
    );
    await expectLater(
      body,
      throwsA(
        isA<ReceiverProtocolException>().having(
          (e) => e.statusCode,
          'status',
          408,
        ),
      ),
    );
    timer.cancel();
    await input.close();
  });

  test(
    'browser preview queues jobs without native sockets or pairing claims',
    () async {
      final receiver = preview.LocalReceiverService();
      addTearDown(receiver.dispose);
      expect(receiver.supportsNativeReceiver, false);
      await receiver.start();
      expect(receiver.currentStatus.state, ReceiverState.simulation);
      expect(receiver.pairingToken, isNull);
      final incoming = receiver.pendingJobs.first;
      receiver.simulateIncomingJob(jobJson());
      expect(identical(await incoming, receiver.pendingQueue.single), true);
      receiver.acknowledgePendingJob(receiver.pendingQueue.single);
      expect(receiver.pendingQueue, isEmpty);
      await receiver.setForeground(false);
      expect(
        () => receiver.simulateIncomingJob(jobJson()),
        throwsA(isA<ReceiverProtocolException>()),
      );
    },
  );

  group('native HTTP receiver', () {
    late LocalReceiverService receiver;
    late HttpClient client;

    setUp(() async {
      receiver = LocalReceiverService(
        port: 0,
        bindAddress: '127.0.0.1',
        maxBodyBytes: 1024,
        maxPendingJobs: 2,
        allowedOrigins: {'https://designer.example'},
      );
      client = HttpClient();
      await receiver.start();
    });
    tearDown(() async {
      client.close(force: true);
      await receiver.dispose();
    });

    Future<(int, Map<String, dynamic>)> request({
      String path = '/api/v1/jobs',
      String method = 'POST',
      String? token,
      String? body,
      String? origin,
      String contentType = 'application/json',
    }) async {
      final req = await client.openUrl(
        method,
        Uri.parse('http://127.0.0.1:${receiver.currentStatus.port}$path'),
      );
      if (token != null) req.headers.set('Authorization', 'Bearer $token');
      if (origin != null) req.headers.set('Origin', origin);
      req.headers.set('Content-Type', contentType);
      if (body != null) req.write(body);
      final response = await req.close();
      final text = await utf8.decoder.bind(response).join();
      return (
        response.statusCode,
        text.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(text) as Map<String, dynamic>,
      );
    }

    test(
      'requires token and emits pending proposal, status never reveals token',
      () async {
        expect(receiver.endpoints.single.host, '127.0.0.1');
        expect(receiver.endpoints.single.port, receiver.currentStatus.port);
        final json = jsonEncode(jobJson());
        expect((await request(body: json)).$1, 401);
        expect((await request(token: 'wrong', body: json)).$1, 401);
        final event = receiver.pendingJobs.first;
        final response = await request(
          token: receiver.pairingToken,
          body: json,
        );
        expect(response.$1, 202);
        expect(response.$2['status'], 'pending');
        expect(identical(await event, receiver.pendingQueue.single), true);
        expect(receiver.currentStatus.endpoints, receiver.endpoints);
        expect(receiver.endpoints, isNotEmpty);
        final status = await request(path: '/api/v1/status', method: 'GET');
        expect(status.$1, 200);
        expect(status.$2['pending_count'], 1);
        expect(jsonEncode(status.$2), isNot(contains(receiver.pairingToken!)));
        expect(status.$2.containsKey('jobs'), false);
      },
    );

    test(
      'reports routes, media, JSON, validation, size and queue errors',
      () async {
        final token = receiver.pairingToken;
        expect((await request(path: '/unknown')).$1, 404);
        expect((await request(method: 'GET')).$1, 405);
        expect(
          (await request(
            token: token,
            contentType: 'text/plain',
            body: '{}',
          )).$1,
          415,
        );
        expect(
          (await request(token: token, body: '{')).$2['error']['code'],
          'invalid_json',
        );
        expect(
          (await request(token: token, body: '{}')).$2['error']['code'],
          'invalid_job',
        );
        expect((await request(token: token, body: ' ' * 1025)).$1, 413);
        expect(receiver.pendingQueue, isEmpty);
        expect(
          (await request(token: token, body: jsonEncode(jobJson('1')))).$1,
          202,
        );
        expect(
          (await request(token: token, body: jsonEncode(jobJson('2')))).$1,
          202,
        );
        expect(
          (await request(token: token, body: jsonEncode(jobJson('3')))).$1,
          429,
        );
        receiver.acknowledgePendingJob(receiver.pendingQueue.first);
        expect(
          (await request(token: token, body: jsonEncode(jobJson('3')))).$1,
          202,
        );
      },
    );

    test(
      'rejects untrusted browser origins; trusted origin still requires pairing',
      () async {
        expect(
          (await request(
            origin: 'https://untrusted.example',
            token: receiver.pairingToken,
            body: jsonEncode(jobJson()),
          )).$1,
          403,
        );
        expect(
          (await request(
            origin: 'https://designer.example',
            body: jsonEncode(jobJson()),
          )).$1,
          401,
        );
        expect(
          (await request(
            origin: 'https://designer.example',
            token: receiver.pairingToken,
            body: jsonEncode(jobJson()),
          )).$1,
          202,
        );
        expect(
          (await request(
            origin: 'https://designer.example',
            method: 'OPTIONS',
          )).$1,
          204,
        );
      },
    );

    test(
      'foreground lifecycle stops/unpairs and resume needs explicit start',
      () async {
        final oldToken = receiver.pairingToken;
        await receiver.setForeground(false);
        expect(receiver.pairingToken, isNull);
        expect(receiver.currentStatus.isRunning, false);
        expect(receiver.start, throwsStateError);
        await receiver.setForeground(true);
        expect(receiver.currentStatus.isRunning, false);
        await receiver.start();
        expect(receiver.pairingToken, isNot(oldToken));
        expect(
          (await request(token: oldToken, body: jsonEncode(jobJson()))).$1,
          401,
        );
      },
    );

    test('stop during bind cannot leave a receiver listening', () async {
      await receiver.stop();
      final opening = receiver.start();
      await receiver.stop();
      await opening;
      expect(receiver.currentStatus.isRunning, false);
      expect(receiver.pairingToken, isNull);
    });
  });
}
