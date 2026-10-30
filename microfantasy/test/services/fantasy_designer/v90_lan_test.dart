import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/services/fantasy_designer/local_receiver_service.dart';

Map<String, Object?> fixture() => Map<String, Object?>.from(
  jsonDecode(File('examples/v90-cut-helper.json').readAsStringSync()),
);
void main() {
  test(
    'LAN preflight and paired browser upload deliver the same complete helper',
    () async {
      final receiver = LocalReceiverService(
        port: 0,
        bindAddress: '127.0.0.1',
        allowBrowserPairing: true,
      );
      final client = HttpClient();
      addTearDown(receiver.dispose);
      addTearDown(() => client.close(force: true));
      await receiver.start();
      final base = receiver.endpoints.single;
      const origin = 'https://asdii.github.io';
      final preflight = await client.openUrl(
        'OPTIONS',
        base.resolve('/api/v1/jobs'),
      );
      preflight.headers.set('Origin', origin);
      preflight.headers.set('Access-Control-Request-Method', 'POST');
      preflight.headers.set(
        'Access-Control-Request-Headers',
        'authorization,content-type',
      );
      preflight.headers.set('Access-Control-Request-Private-Network', 'true');
      final preflightResponse = await preflight.close();
      expect(preflightResponse.statusCode, 204);
      expect(
        preflightResponse.headers.value('access-control-allow-origin'),
        origin,
      );
      expect(
        preflightResponse.headers.value('access-control-allow-private-network'),
        'true',
      );
      await preflightResponse.drain<void>();
      final status = await client.getUrl(base.resolve('/api/v1/status'));
      status.headers.set('Origin', origin);
      final statusData = jsonDecode(
        await utf8.decoder.bind(await status.close()).join(),
      );
      expect(statusData['cut_helper_versions'], [1]);
      final received = receiver.pendingJobs.first;
      final post = await client.postUrl(base.resolve('/api/v1/jobs'));
      post.headers.set('Origin', origin);
      post.headers.set('Authorization', 'Bearer ${receiver.pairingToken}');
      post.headers.contentType = ContentType.json;
      post.write(jsonEncode(fixture()));
      final response = await post.close();
      expect(response.statusCode, 202);
      final receipt = jsonDecode(await utf8.decoder.bind(response).join());
      expect(receipt['job_id'], 'v90-contract-fixture');
      expect(receipt['cut_helper_version'], 1);
      expect((await received).toJson(), fixture());
      final outsider = await client.getUrl(base.resolve('/api/v1/status'));
      outsider.headers.set('Origin', 'https://different-page.example');
      final rejected = await outsider.close();
      expect(rejected.statusCode, 403);
      await rejected.drain<void>();
    },
  );
}
