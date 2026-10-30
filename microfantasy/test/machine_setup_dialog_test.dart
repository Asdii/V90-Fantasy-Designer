import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/screens/settings/machine_setup_dialog.dart';
import 'package:microfantasy/services/esp32/provisioning_service.dart';

class FakeSetup implements MachineProvisioningService {
  bool saved = false;
  String? ssid;
  @override
  Future<MachineSetupStatus> status() async => MachineSetupStatus(
    connected: saved,
    connecting: false,
    ip: saved ? '192.168.1.80' : '0.0.0.0',
    error: '',
  );
  @override
  Future<void> configure(String ssid, String password) async {
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
}
