import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/screens/settings/machine_setup_dialog.dart';
import 'package:microfantasy/services/esp32/provisioning_service.dart';

class FakeSetup implements MachineProvisioningService {
  bool saved = false;
  String? ssid;
  Exception? rejection;
  String connectionError = '';
  @override
  Future<MachineSetupStatus> status() async => MachineSetupStatus(
    connected: saved && connectionError.isEmpty,
    connecting: false,
    ip: saved ? '192.168.1.80' : '0.0.0.0',
    error: saved ? connectionError : '',
  );
  @override
  Future<void> configure(String ssid, String password) async {
    if (rejection != null) throw rejection!;
    this.ssid = ssid;
    saved = true;
  }
}

void main() {
  testWidgets('Wi-Fi assistant configures and confirms on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = FakeSetup();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MachineSetupDialog(service: service)),
      ),
    );
    await tester.tap(find.text('Ya estoy conectado: comprobar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'My Wi-Fi');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.ensureVisible(find.text('Guardar Wi-Fi en la máquina'));
    await tester.tap(find.text('Guardar Wi-Fi en la máquina'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(service.ssid, 'My Wi-Fi');
    expect(find.text('Terminar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final code in [400, 403, 409]) {
    testWidgets('Wi-Fi rejection $code shows its cause and allows retry', (
      tester,
    ) async {
      final error = MachineSetupRequestException(code);
      final service = FakeSetup()..rejection = error;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MachineSetupDialog(service: service)),
        ),
      );
      await tester.tap(find.text('Ya estoy conectado: comprobar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'My Wi-Fi');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await tester.ensureVisible(find.text('Guardar Wi-Fi en la máquina'));
      await tester.tap(find.text('Guardar Wi-Fi en la máquina'));
      await tester.pumpAndSettle();
      expect(find.text(error.message), findsOneWidget);
      expect(find.textContaining('No se pudo enviar.'), findsNothing);
      expect(find.text('Terminar'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        'password123',
      );
      service.rejection = null;
      await tester.ensureVisible(find.text('Guardar Wi-Fi en la máquina'));
      await tester.tap(find.text('Guardar Wi-Fi en la máquina'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Wi-Fi guardado en la máquina.'), findsOneWidget);
      expect(find.text('Terminar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('NVS failure is not reported as saved Wi-Fi', (tester) async {
    final service = FakeSetup()..connectionError = 'storage_error';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MachineSetupDialog(service: service)),
      ),
    );
    await tester.tap(find.text('Ya estoy conectado: comprobar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'My Wi-Fi');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.ensureVisible(find.text('Guardar Wi-Fi en la máquina'));
    await tester.tap(find.text('Guardar Wi-Fi en la máquina'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No se pudo guardar en la máquina.'),
      findsOneWidget,
    );
    expect(find.text('Wi-Fi guardado en la máquina.'), findsNothing);
    expect(find.text('Terminar'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
