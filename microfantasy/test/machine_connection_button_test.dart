import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/app/theme.dart';
import 'package:microfantasy/widgets/machine_connection_button.dart';

void main() {
  final action = find.byKey(const ValueKey('machine-connection-action'));

  Future<void> mount(
    WidgetTester tester, {
    bool connected = false,
    bool connecting = false,
    bool simulation = false,
    bool enabled = true,
    bool reducedMotion = false,
    bool accessibleNavigation = false,
    Future<void> Function()? reconnect,
    Future<void> Function()? useReal,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: microTheme(),
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: reducedMotion,
            accessibleNavigation: accessibleNavigation,
          ),
          child: Scaffold(
            body: Center(
              child: MachineConnectionButton(
                connected: connected,
                connecting: connecting,
                simulation: simulation,
                enabled: enabled,
                onReconnect: reconnect ?? () async {},
                onUseRealMachine: useReal ?? () async {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('retry is immediate and taps cannot overlap a pending request', (
    tester,
  ) async {
    final pending = Completer<void>();
    var attempts = 0;
    await mount(
      tester,
      reconnect: () {
        attempts++;
        return pending.future;
      },
    );
    await tester.tap(action);
    expect(attempts, 1);
    await tester.pump();
    expect(find.text('Buscando…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(action);
    await tester.pump();
    expect(attempts, 1);
    expect(tester.widget<TextButton>(action).onPressed, isNull);
    pending.complete();
    await tester.pump();
    expect(tester.widget<TextButton>(action).onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('controller busy and calibration lock disable requests', (
    tester,
  ) async {
    var attempts = 0;
    Future<void> reconnect() async {
      attempts++;
    }

    await mount(
      tester,
      connecting: true,
      reconnect: reconnect,
      reducedMotion: true,
    );
    await tester.tap(action);
    expect(attempts, 0);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      isNotNull,
    );
    await mount(tester, connected: true, enabled: false, reconnect: reconnect);
    await tester.tap(action);
    expect(attempts, 0);
    expect(find.text('Conectada'), findsOneWidget);
    expect(find.text('Buscando…'), findsNothing);
  });

  testWidgets('simulation changes mode only after explicit confirmation', (
    tester,
  ) async {
    var attempts = 0;
    var switches = 0;
    await mount(
      tester,
      simulation: true,
      reconnect: () async {
        attempts++;
      },
      useReal: () async {
        switches++;
      },
    );
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.text('Modo simulación'), findsOneWidget);
    expect(switches, 0);
    await tester.tap(find.text('Seguir simulando'));
    await tester.pumpAndSettle();
    expect(switches, 0);
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conectar máquina real'));
    await tester.pumpAndSettle();
    expect(switches, 1);
    expect(attempts, 0);
  });

  testWidgets(
    'pulse is subtle and stops for either reduced-motion preference',
    (tester) async {
      Color? background() =>
          tester.widget<TextButton>(action).style!.backgroundColor!.resolve({});
      await mount(tester);
      final initial = background();
      await tester.pump(const Duration(milliseconds: 900));
      expect(background(), isNot(initial));
      await mount(tester, reducedMotion: true);
      await tester.pumpAndSettle();
      final reduced = background();
      await tester.pump(const Duration(seconds: 2));
      expect(background(), reduced);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await mount(tester, accessibleNavigation: true);
      await tester.pumpAndSettle();
      final accessible = background();
      await tester.pump(const Duration(seconds: 2));
      expect(background(), accessible);
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );

  testWidgets('48px accessible action and failed request remains retryable', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await mount(
        tester,
        reducedMotion: true,
        reconnect: () async {
          throw StateError('offline');
        },
      );
      expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(action).width, greaterThanOrEqualTo(48));
      expect(
        find.bySemanticsLabel('Máquina desconectada. Conectar ahora'),
        findsOneWidget,
      );
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('Reintentar'), findsOneWidget);
      expect(tester.widget<TextButton>(action).onPressed, isNotNull);
      expect(find.byType(SnackBar), findsNothing);
    } finally {
      semantics.dispose();
    }
  });
}
