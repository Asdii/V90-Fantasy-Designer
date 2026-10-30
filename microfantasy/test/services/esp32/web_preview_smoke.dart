// Compile with `dart compile js` to verify the conditional browser imports.
import 'package:microfantasy/services/fantasy_designer/local_receiver_service.dart';
import 'package:microfantasy/services/esp32/esp32_discovery.dart';
import 'package:microfantasy/services/esp32/mock_esp32_service.dart';
import 'package:microfantasy/services/esp32/websocket_esp32_service.dart';

Future<void> main() async {
  final mock = MockEsp32Service();
  final receiver = LocalReceiverService();
  final real = WebSocketEsp32Service();
  final discovery = Esp32Discovery();
  await mock.connect();
  mock.setPosition(42);
  await receiver.start();
  receiver.simulateIncomingJob({
    'jobId': 'preview',
    'name': 'Preview',
    'units': 'mm',
    'steps': [
      {'index': 1, 'angleR': 0, 'x': 1, 'depth': 0.1},
    ],
  });
  await real.connect(Uri.parse('ws://fantasy-machine.local:81/ws'));
  if (mock.currentPosition?.xMm != 42 ||
      receiver.supportsNativeReceiver ||
      receiver.pendingQueue.length != 1 ||
      receiver.endpoints.isNotEmpty ||
      real.currentStatus.state != Esp32ConnectionState.unsupported ||
      discovery.isSupported) {
    throw StateError('Browser service contract failed');
  }
  await mock.dispose();
  await receiver.dispose();
  await real.dispose();
  await discovery.dispose();
}
