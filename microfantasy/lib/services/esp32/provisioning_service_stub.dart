import 'provisioning_service.dart';

class HttpMachineProvisioningService implements MachineProvisioningService {
  HttpMachineProvisioningService({
    Uri? endpoint,
    Duration timeout = const Duration(seconds: 5),
  });
  @override
  Future<MachineSetupStatus> status() async => throw UnsupportedError(
    'Usa la app Android o iOS para configurar la máquina.',
  );
  @override
  Future<void> configure(String ssid, String password) async =>
      throw UnsupportedError(
        'Usa la app Android o iOS para configurar la máquina.',
      );
}
