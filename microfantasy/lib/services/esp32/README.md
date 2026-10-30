# ESP32 communication API

Parent app dependency: `nsd: ^4.1.0` (installed). The implementation uses the
startDiscovery/stopDiscovery API also in current 5.0.1 pub.dev docs (checked 2026-10-30).

```dart
import 'services/esp32/esp32_service.dart';
import 'services/esp32/mock_esp32_service.dart';
import 'services/esp32/websocket_esp32_service.dart';
import 'services/esp32/esp32_discovery.dart';

final mock = MockEsp32Service();
await mock.connect();
mock.setPosition(12.3); // Bind a manual simulation slider here.
mock.startSimulation(minMm: 0, maxMm: 20);
mock.stopSimulation();

final real = WebSocketEsp32Service(); // allowZeroX defaults false.
await real.connect(Uri.parse('ws://fantasy-machine.local:81/ws'));
// All services: positionStream, statusStream, currentPosition, currentStatus,
// connect([Uri? endpoint]), disconnect(), zeroX(), dispose().

final discovery = Esp32Discovery();
discovery.devicesStream.listen((devices) { /* devices[i].endpoint */ });
await discovery.start();
await discovery.stop();
```

`Esp32Position`: `double xMm`, `DateTime receivedAt`.
`Esp32Status`: `Esp32ConnectionState state`, `String? message`, `Uri? endpoint`,
`String? deviceStatus`, `int reconnectAttempt`, `bool isConnected`.
States: disconnected, connecting, connected, reconnecting, unsupported, error.
Streams broadcast updates; read current getters for the initial snapshot.
The connected mock republishes its current X every 100ms, including manual slider
mode, with a fresh receivedAt. `telemetryInterval` configures this heartbeat.
`stopSimulation()` stops oscillation; only `disconnect()` stops telemetry.

Telemetry protocol: UTF-8 JSON objects `{ "type": "position", "x_mm": 12.3 }`
or `{ "type": "status", "connected": true }` / `connected: false`.
`connected` must be a boolean; no status string is required. Optional descriptive
`status` strings (for example `"ready"`) remain supported. A position can include
`connected`/`status`; a status can include `x_mm`. Untyped objects with these keys
are accepted.
Position must be finite numeric millimetres. No incoming message is executed as a
command. Invalid telemetry is reported through status without crashing listeners.
`connected: false` clears `currentPosition` and emits a disconnected status, even
if that frame includes `x_mm`. It emits no position or synthetic zero. The socket
stays open, but neither malformed messages nor a descriptive status string can
restore connected state. A valid new position or `connected: true` restores the
state; true alone does not restore or emit the previous position. A WebSocket
handshake also waits for either of those valid signals before reporting connected.
Connection loss/disconnect clears the cached native reading. UI consumers must
invalidate their cached readings on a non-connected status and require a fresh
position before displaying a centered indication.
Native sockets reconnect with capped backoff, connection timeout, ping/pong, and a
valid-telemetry timeout. Stale connection attempts cannot revive a stopped service.
The sole optional outbound application message is `{ "type": "zero_x" }`;
construct with `allowZeroX: true` and explicitly call `zeroX()` to send it.
No movement, homing, cutting, or job commands exist.

Discovery defaults: `_fantasy-machine._tcp`, WebSocket path `/ws`, scan duration 10s.
Both are configurable because firmware advertisement is not yet specified.
Only resolved services are offered; discovery never connects automatically.
Stop discovery on application pause; dispose it with the owning controller.

The parent owns platform setup (these files deliberately do not alter it):
- Android: INTERNET and CHANGE_WIFI_MULTICAST_STATE permissions.
- iOS: NSLocalNetworkUsageDescription and NSBonjourServices containing the chosen
  service type. Native requirements: Android API 21+, iOS 13+.
- Configure transport policy for local unencrypted networking where required.
- Web uses MockEsp32Service. Native socket/discovery stubs report unsupported.

Sources: https://pub.dev/packages/nsd and
https://pub.dev/documentation/nsd/latest/nsd/startDiscovery.html

Focused verification from the microfantasy directory:
`flutter test test/services/esp32`
Browser conditional imports can be checked with
`dart compile js test/services/esp32/web_preview_smoke.dart`.
