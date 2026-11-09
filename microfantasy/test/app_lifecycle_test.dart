import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/app/app_controller.dart';
import 'package:microfantasy/main.dart';
import 'package:microfantasy/repositories/key_value_store.dart';
import 'package:microfantasy/services/fantasy_designer/local_receiver_service_stub.dart';

// Observe the real app's lifecycle policy. Actual socket teardown, discovery
// and fresh-X recovery are exercised separately in app_connection_test.dart.
class _LifecycleController extends AppController {
  _LifecycleController()
    : super(store: MemoryStore(), designer: LocalReceiverService());

  final visibility = <bool>[];

  @override
  Future<void> foreground(bool value) async => visibility.add(value);
}

void main() {
  Future<_LifecycleController> mount(WidgetTester tester) async {
    final controller = _LifecycleController();
    await controller.initialize();
    await tester.pumpWidget(MicroFantasyApp(controller: controller));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    controller.visibility.clear();
    return controller;
  }

  testWidgets('notification shade and dialogs never request disconnection', (
    tester,
  ) async {
    final controller = await mount(tester);
    for (var i = 0; i < 3; i++) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 4));
      expect(controller.visibility, isNot(contains(false)));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
    }
    expect(controller.visibility, [true, true, true]);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'brief pause keeps connection; long pause releases and resumes once',
    (tester) async {
      final controller = await mount(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 4));
      expect(controller.visibility, [true]);
      controller.visibility.clear();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 4));
      expect(controller.visibility, [false]);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(controller.visibility, [false, true]);

      controller.visibility.clear();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 4));
      expect(controller.visibility, isEmpty); // No delayed work after disposal.
    },
  );
}
