# Fantasy Designer receiver API

```dart
import 'services/fantasy_designer/fantasy_designer_service.dart';
import 'services/fantasy_designer/local_receiver_service.dart';

final receiver = LocalReceiverService(port: 8787, allowBrowserPairing: true);
receiver.pendingJobs.listen((job) { /* Show approval; do not replace active job. */ });
await receiver.start(); // Explicit foreground receiver toggle.
final tokenToDisplayToUser = receiver.pairingToken;
final actualAddresses = receiver.endpoints; // Real interface IPs and bound port.
await receiver.setForeground(false); // Lifecycle inactive/paused/detached.
await receiver.stop(); // Toggle off. Starting again creates a fresh token.
```

Interface `FantasyDesignerService` signatures:
- `Stream<FantasyJob> get pendingJobs`
- `List<FantasyJob> get pendingQueue` (immutable snapshot, survives stop/start)
- `Stream<ReceiverStatus> get statusStream`
- `ReceiverStatus get currentStatus`
- `String? get pairingToken`
- `List<Uri> get endpoints` (same as `currentStatus.endpoints`; immutable)
- `bool get supportsNativeReceiver`
- `Future<void> start()`, `stop()`, `setForeground(bool)`, `dispose()`
- `void acknowledgePendingJob(FantasyJob job)` (remove accepted/rejected proposal)

`ReceiverStatus` has `state`, `isForeground`, `port`, `endpoints`, `pendingCount`, `message`,
`isRunning`. States: stopped, starting, listening, simulation, error.
LocalReceiverService additionally exposes `simulateIncomingJob(Map<String,dynamic>)`.
Constructor: `LocalReceiverService({int port = 8787, String bindAddress = '0.0.0.0',
int maxBodyBytes = 1048576, int maxPendingJobs = 10,
Duration bodyTimeout = const Duration(seconds: 10), Set<String> allowedOrigins = const {},
bool allowBrowserPairing = false})`.
Native `endpoints` lists HTTP base URLs using the bound port and actual local
network interface addresses. The UI can show each URL with `/api/v1/jobs` appended.
It is empty while stopped, in web simulation, or if no usable interface is found;
there is no placeholder address. A fixed bind address yields that address only.
Wi-Fi/VPN changes require stopping and restarting the foreground receiver to refresh.
On web start enables simulation only: no LAN socket is created or advertised.

Native HTTP contract:
- `POST /api/v1/jobs`, `Content-Type: application/json`,
  `Authorization: Bearer <pairingToken>` (or `X-Pairing-Token`): body is the direct
  FantasyJob JSON object. 202 means queued pending explicit local approval.
- `GET /api/v1/status`: minimal state/pending count; no token or job contents.
  Includes `cut_helper_versions: [1]` and `max_job_bytes` for negotiation.
- Successful POST replies with `status: pending`, `job_id`, `pending_count`,
  and `cut_helper_version: 1` for a full helper (null for a simple legacy job).
- JSON errors `{ "error": { "code": "...", "message": "..." } }`.
- 400 invalid JSON/model, 401 missing/incorrect token, 404 unknown route,
  405 incorrect method, 408 body timeout, 413 too large, 415 unsupported media or
  encoding, 429 pending queue full, 503 receiver no longer active.
- Defaults: 1 MiB body limit, 10s total body timeout, 10 queued jobs. Limits are
  constructor options. Content-Length and streamed bytes are both checked.
- Tokens are generated securely per listening session, never in status/logs,
  invalidated when stopped/backgrounded. No automatic resume in the background.
- Optional `allowedOrigins` enables exact-origin CORS for a browser Designer.
  The strict constructor default rejects other Origin-bearing requests.
- The shipped app opts into `allowBrowserPairing: true`. A syntactically valid
  HTTP(S) origin can preflight/query minimal status, but only a valid authenticated
  POST binds it to the current session. Later other origins are rejected until
  the receiver is restarted. Preflight never pairs; tokens remain mandatory.
  CORS also handles Private Network Access preflight when requested.
  Use a trusted LAN; HTTP does not encrypt the token.

The model contract is only `FantasyJob.fromJson(Map<String,dynamic>)` and
`toJson()`. The receiver validates then queues; it owns no active-job reference.
The current model requires `jobId`, `name`, `units: "mm"`, and `steps` with
`index`, `angleR`, `x`, `depth` (plus optional `preview` and `cutHelper` v1).
The full Cut Helper contract and shared fixture are documented in
`docs/microfantasy-lan.md` at the repository root.
No pubspec or platform files are modified by this layer.

Focused verification from the microfantasy directory:
`flutter test test/services/fantasy_designer`
