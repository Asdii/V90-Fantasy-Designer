import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/app/update_controller.dart';
import 'package:microfantasy/app/app_controller.dart';
import 'package:microfantasy/main.dart';
import 'package:microfantasy/repositories/key_value_store.dart';
import 'package:microfantasy/services/fantasy_designer/local_receiver_service.dart';
import 'package:microfantasy/services/updates/app_update_service.dart';
import 'package:microfantasy/services/updates/github_update_service.dart';
import 'package:microfantasy/widgets/app_updates.dart';

final certificate = 'a' * 64;
Map<String, dynamic> manifest({int code = 200}) => {
  'schemaVersion': 1,
  'versionName': '1.0.8',
  'versionCode': code,
  'applicationId': 'app.microfantasy.microfantasy',
  'sha256': 'f' * 64,
  'certificateSha256': certificate,
  'notes': 'Mejoras en Cut Helper',
  'apkUrl':
      'https://github.com/Asdii/V90-Fantasy-Designer/releases/download/microfantasy-b$code/microfantasy.apk',
};

class FakeUpdates implements AppUpdateService {
  int checks = 0, downloads = 0;
  bool fail = false;
  Completer<AppRelease?>? pending;
  InstalledApp current = InstalledApp(
    '1.0.0',
    2,
    'app.microfantasy.microfantasy',
    certificate,
  );
  AppRelease? release = AppRelease.fromJson(manifest());
  @override
  bool get supported => true;
  @override
  Future<InstalledApp> installedApp() async => current;
  @override
  Future<AppRelease?> latestRelease() async {
    checks++;
    if (fail) throw Exception('Offline');
    return pending == null ? release : pending!.future;
  }

  @override
  Future<void> openDownload(AppRelease release) async {
    downloads++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('release contract rejects invalid or external APK links', () {
    expect(AppRelease.fromJson(manifest()).toJson(), manifest());
    for (final change in <Map<String, dynamic>>[
      {'schemaVersion': 2},
      {'versionCode': 0},
      {'versionCode': 200.5},
      {'certificateSha256': 'invalid'},
      {'applicationId': 'other.app'},
      {
        'apkUrl':
            'http://github.com/Asdii/V90-Fantasy-Designer/releases/download/microfantasy-b200/microfantasy.apk',
      },
      {'apkUrl': 'https://other.example/app.apk'},
      {
        'apkUrl':
            'https://github.com/other/repo/releases/download/microfantasy-b200/microfantasy.apk',
      },
    ]) {
      expect(
        () => AppRelease.fromJson({...manifest(), ...change}),
        throwsFormatException,
      );
    }
  });
  test(
    'checks daily, manual check bypasses interval, preference persists',
    () async {
      var now = DateTime.utc(2026, 10, 30);
      final store = MemoryStore(), service = FakeUpdates();
      final c = UpdateController(store, service, now: () => now);
      await c.initialize();
      expect(c.showBanner, true);
      await c.check();
      expect(service.checks, 1);
      c.later();
      expect(c.showBanner, false);
      await c.check(manual: true);
      expect(service.checks, 2);
      now = now.add(const Duration(days: 1));
      await c.check();
      expect(service.checks, 3);
      await c.setAutomatic(false);
      await c.flush();
      c.dispose();
      final second = UpdateController(
        store,
        service,
        now: () => now.add(const Duration(days: 2)),
      );
      await second.initialize();
      expect(second.automatic, false);
      expect(service.checks, 3);
      expect(second.available!.versionCode, 200);
      await second.check(manual: true);
      expect(service.checks, 4);
      second.dispose();
    },
  );
  test(
    'no downgrade or same-version reinstall; installed update clears cached offer',
    () async {
      final store = MemoryStore(), service = FakeUpdates();
      final first = UpdateController(store, service);
      await first.initialize();
      first.dispose();
      service.current = InstalledApp(
        '1.0.8',
        200,
        'app.microfantasy.microfantasy',
        certificate,
      );
      final next = UpdateController(store, service);
      await next.initialize();
      expect(next.available, isNull);
      service.release = AppRelease.fromJson(manifest(code: 199));
      await next.check(manual: true);
      expect(next.available, isNull);
      expect(next.status, 'Tienes la última versión.');
      next.dispose();
    },
  );
  test(
    'rejects a different signer and never opens incompatible download',
    () async {
      final service = FakeUpdates()
        ..release = AppRelease.fromJson({
          ...manifest(),
          'certificateSha256': 'b' * 64,
        });
      final c = UpdateController(MemoryStore(), service);
      await c.initialize();
      expect(c.available, isNull);
      expect(c.status, contains('otra firma'));
      await c.download();
      expect(service.downloads, 0);
      c.dispose();
    },
  );
  test(
    'offline failure preserves pending update and unrelated session data',
    () async {
      final store = MemoryStore({'microfantasy.session.v1': 'keep work'}),
          service = FakeUpdates();
      final c = UpdateController(store, service);
      await c.initialize();
      service.fail = true;
      await c.check(manual: true);
      expect(c.available!.versionCode, 200);
      expect(c.status, contains('Revisa internet'));
      expect(await store.getString('microfantasy.session.v1'), 'keep work');
      c.dispose();
    },
  );
  test('serializes checks and stops updating UI after disposal', () async {
    final service = FakeUpdates()..pending = Completer<AppRelease?>();
    final c = UpdateController(MemoryStore(), service);
    final checking = c.initialize();
    await Future<void>.delayed(Duration.zero);
    await c.check(manual: true);
    expect(service.checks, 1);
    c.dispose();
    service.pending!.complete(service.release);
    await checking;
  });
  test(
    'Android adapter reads actual installed version and opens only explicit download',
    () async {
      const channel = MethodChannel('app.microfantasy/updates');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'installedApp') {
              return {
                'versionName': '1.0.8',
                'versionCode': 200,
                'applicationId': 'app.microfantasy.microfantasy',
                'certificateSha256': certificate,
              };
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final service = GithubUpdateService();
      expect((await service.installedApp()).versionCode, 200);
      expect(calls.length, 1);
      await service.openDownload(AppRelease.fromJson(manifest()));
      expect(calls.last.method, 'openDownload');
      expect(calls.last.arguments['url'], manifest()['apkUrl']);
    },
  );
  testWidgets('available update does not block cutting on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late AppController controller;
    await tester.runAsync(() async {
      controller = AppController(
        store: MemoryStore(),
        designer: LocalReceiverService(port: 0, bindAddress: '127.0.0.1'),
        updateService: FakeUpdates(),
      );
      await controller.initialize();
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpWidget(MicroFantasyApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Nueva versión 1.0.8'), findsOneWidget);
    await tester.tap(find.text('Siguiente'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.stepIndex, 1);
    await tester.tap(find.text('Más tarde'));
    await tester.pump();
    expect(find.text('Nueva versión 1.0.8'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.runAsync(controller.flush);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets(
    'update banner dismisses and settings buttons perform their actions',
    (tester) async {
      final service = FakeUpdates();
      final controller = UpdateController(MemoryStore(), service);
      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                AppUpdateBanner(controller: controller),
                AppUpdatesCard(controller: controller),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Más tarde'));
      await tester.pump();
      expect(controller.showBanner, false);
      await tester.tap(find.text('Actualizar'));
      await tester.pump();
      expect(service.downloads, 1);
      await tester.tap(find.text('Buscar actualizaciones'));
      await tester.pump();
      expect(service.checks, 2);
      expect(tester.takeException(), isNull);
      controller.dispose();
    },
  );
}
