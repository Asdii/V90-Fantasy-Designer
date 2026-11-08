# ESP32 communication API

The matching XIAO ESP32-C3 + AS5311 firmware is in
[`firmware/microfantasy-xiao`](../../../../../firmware/microfantasy-xiao/README.md).
Settings → Configurar Wi-Fi de la máquina uses `MachineProvisioningService`,
separate from telemetry, to configure the first-boot AP. The password is never
stored by the app. Join its Wi-Fi once through the phone's system settings;
after setup use the home LAN, port 81, path `/ws` and `_fantasy-machine._tcp`.

Provisioning v1 advertises optional `scan_supported` in its status. New firmware
supports `POST /api/v1/setup/networks` to start a scan and `GET` to poll
`{device, schemaVersion, scanning, error, networks:[{ssid,rssi,secured}]}`.
Old firmware retains manual SSID entry. Connection progress exposes `phase`,
`attempt`, `max_attempts`, `reason_code`; the app waits up to 110 s for scanning
and three automatic firmware attempts, surviving temporary AP channel changes.
Only a confirmed connection without a storage error is shown as saved.

Parent app dependency: `nsd: ^4.1.0` (installed). Discovery uses its
startDiscovery/stopDiscovery API with resolved IPv4 addresses.

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

final real = WebSocketEsp32Service(
  resolver: Esp32Discovery(),
  // deviceId: savedMachineId, // Optional until the first verified connection.
); // allowZeroX defaults false.
await real.connect(Uri.parse('ws://fantasy-machine.local:81/ws'));
// All services: positionStream, statusStream, currentPosition, currentStatus,
// connect([Uri? endpoint]), disconnect(), zeroX(), dispose().

// Standalone lookup, if needed; the real service owns its resolver above.
final discovery = Esp32Discovery();
final device = await discovery.resolve(Uri.parse('ws://192.168.1.84:81/ws'));
// device?.endpoint is the verified address, which may now be .82.
await discovery.dispose();
```

`Esp32Position`: `double xMm`, `DateTime receivedAt`.
`Esp32Status`: `Esp32ConnectionState state`, `String? message`, `Uri? endpoint`,
`String? deviceStatus`, `String? deviceId`, `int reconnectAttempt`, `bool isConnected`.
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
Legacy `{ "type": "zero_x" }` requires `allowZeroX: true` and an explicit
`zeroX()` call. Physical table referencing uses the acknowledged command below.
Neither command moves the axis. No movement, cutting, or job execution API exists.

### Physical X reference (capability `set_x_reference`)

The optional `XReferenceEsp32Service` interface is implemented by the native
WebSocket service and mock. Old firmware remains readable without this capability.
Status advertises `capabilities: ["set_x_reference"]`. Status and **every position**
include `boot_id` (new on power-on), nullable `reference_id`, and integer
`reference_revision` (zero until the first coordinate change).

Only an explicit center/stop confirmation sends:

```json
{"type":"set_x_reference","request_id":"unique-request","boot_id":"current-boot","reference_id":"saved-physical-frame","x_mm":-32.125}
```

The board sets its RAM offset at the current encoder count and answers:

```json
{"type":"reference_ack","request_id":"unique-request","accepted":true,"boot_id":"current-boot","reference_id":"saved-physical-frame","reference_revision":1,"x_mm":-32.125}
```

Failure returns `accepted: false` and an `error` without changing coordinates.
The app validates ID, boot, frame, finite coordinate and revision, waits up to
5 s for confirmation, and does **not** retry coordinate commands automatically.
Duplicate in-flight commands are blocked. Disconnect/reboot cancels a pending
confirmation. Old-revision samples cannot restore the previous coordinate frame.
Firmware caches recent successful requests idempotently, so retransmission of
the same command cannot re-anchor at a different physical count.

`XAxisRepository` stores signed stop distances and the physical frame ID, per
device, only on user actions. The app persists a new center's intended ID before
sending it. If acknowledgement is lost, matching live telemetry can confirm the
intended frame; otherwise it remains unreferenced. A stored number alone never
enables position confirmation. `sensorX` may display fresh unreferenced readings
in calibration; `actualX` gates cutting until the stored frame matches the live
boot, reference ID and revision. Ordinary network reconnection sends no reference
command. A fresh boot has no reference: the user must physically confirm a stop.

The mock supports `simulateRestart()` for testing power loss, whereas
`disconnect()`/`connect()` preserve the same boot/frame. `setPosition()` supplies
manual simulated motion; `setXReference()` assigns the confirmed coordinate.

### Discovery and recovery

Every connection/reconnection races the last address, `fantasy-machine.local`,
the setup AP (`192.168.4.1`), fresh DNS-SD `_fantasy-machine._tcp` and a UDP local
broadcast on port **42190**. A round lasts at most 3 s and finishes as soon as a
verified candidate responds; individual HTTP probes expire after 700 ms. There
is no subnet-wide HTTP scan. UDP queries repeat every 500 ms during that round.

UDP request: `{"type":"discover","api_version":1,"nonce":"random-token"}`.
Only matching replies (`type: discovery`, `service: microfantasy-machine`,
`api_version: 1`, same nonce) become candidates. The reply's source address is
used; its advertised `ip` is never trusted as the connection destination.

Each candidate must answer `GET /api/v1/info` with `service`, `api_version`,
`device_id`, `ws_port` and `ws_path`. HTTP redirects are rejected. The connected
HTTP peer address selects the socket destination; the WebSocket must then repeat
the expected identity in its first valid status. This prevents an old address
reassigned to a different device from providing readings. Identity derives from
the board MAC; it is not pairing or cryptographic authentication.

Only after WebSocket confirmation does `AppController` persist the address and
identity. This update does not restart the connection or change the calibration.
Before an identity is known, old firmware can identify itself through the existing
`/api/v1/apps` service marker. Once an ID is remembered, unidentified or different
boards are rejected; explicitly changing the manual hostname or provisioning a
new machine clears that saved ID.

Retry delays are 1, 2, 4, then at most 5 s, with a fresh lookup each time. The app
uses a 2 s WebSocket ping interval and the configured connection/telemetry timeout
(5 s by default). On pause it closes the socket and cancels discovery; on resume
it resolves the machine again. Work, step and calibration are retained. Lost
readings remain invalid until fresh telemetry arrives. Reconnection sends no zero.
All losing HTTP probes, UDP timers/sockets and DNS-SD listeners are cleaned up.
If Bonjour is unavailable, HTTP/UDP can still succeed; if UDP broadcast is blocked,
Bonjour or a known address can still succeed. Isolated Wi-Fi clients/VLANs must
still permit communication; discovery cannot bypass network isolation.

The parent owns platform setup (these files deliberately do not alter it):
- Android: INTERNET and CHANGE_WIFI_MULTICAST_STATE permissions.
- iOS: NSLocalNetworkUsageDescription and NSBonjourServices containing the chosen
  service type. Native requirements: Android API 21+, iOS 13+.
- Configure transport policy for local unencrypted networking where required.
- Web uses MockEsp32Service. Native socket/discovery stubs report unsupported.

Sources: [nsd 4.1.0](https://pub.dev/packages/nsd/versions/4.1.0),
[Android NSD](https://developer.android.com/develop/connectivity/wifi/use-nsd),
[ESPHome mDNS](https://esphome.io/components/mdns/), and
[ESPHome reconnect logic](https://github.com/esphome/aioesphomeapi/blob/main/aioesphomeapi/reconnect_logic.py).

Focused verification from the microfantasy directory:
`flutter test test/services/esp32`
`flutter test test/app_connection_test.dart` also checks persistence without a
reconnect loop, background/resume, and preservation of work and calibration.
Browser conditional imports can be checked with
`dart compile js test/services/esp32/web_preview_smoke.dart`.
