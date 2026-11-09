import 'dart:async';
import 'package:microfantasy/services/esp32/esp32_service.dart';

/// Board state outlives phone sessions, just like a powered ESP32.
class BootMachine {
  String bootId = 'boot-1';
  bool pending = true;
  double x = 17.25;
  int receipts = 0;
  bool dropReceipt = false;
  Future<void> Function()? beforeReceipt;
  final clients = <BootClient>[];
  BootClient client() {
    final client = BootClient(this);
    clients.add(client);
    return client;
  }

  void restart() {
    bootId = 'boot-${int.parse(bootId.split('-').last) + 1}';
    pending = true;
    x = 0;
    broadcast();
  }

  void broadcast() {
    for (final client in clients.toList()) {
      client.publish();
    }
  }
}

class BootClient implements Esp32Service, BootNoticeEsp32Service {
  BootClient(this.board);
  final BootMachine board;
  final _statuses = StreamController<Esp32Status>.broadcast();
  final _positions = StreamController<Esp32Position>.broadcast();
  @override
  Esp32Status currentStatus = const Esp32Status(
    state: Esp32ConnectionState.disconnected,
  );
  @override
  Esp32Position? currentPosition;
  bool connected = false;
  @override
  Stream<Esp32Status> get statusStream => _statuses.stream;
  @override
  Stream<Esp32Position> get positionStream => _positions.stream;
  void publish() {
    if (!connected) return;
    currentStatus = Esp32Status(
      state: Esp32ConnectionState.connected,
      endpoint: Uri.parse('ws://192.168.1.82:81/ws'),
      deviceId: 'board-a',
      bootId: board.bootId,
      referenceRevision: 0,
      supportsBootNotice: true,
      bootNoticePending: board.pending,
    );
    currentPosition = Esp32Position(
      xMm: board.x,
      receivedAt: DateTime.now(),
      bootId: board.bootId,
      referenceRevision: 0,
    );
    _statuses.add(currentStatus);
    _positions.add(currentPosition!);
  }

  @override
  Future<void> connect([Uri? endpoint]) async {
    connected = true;
    publish();
  }

  @override
  Future<void> disconnect() async {
    connected = false;
    currentStatus = const Esp32Status(state: Esp32ConnectionState.disconnected);
    currentPosition = null;
    _statuses.add(currentStatus);
  }

  @override
  Future<void> acknowledgeBoot(String bootId) async {
    if (!connected || bootId != board.bootId) throw StateError('Changed boot');
    await board.beforeReceipt?.call();
    board.receipts++;
    if (board.dropReceipt) return;
    board.pending = false;
    publish();
  }

  @override
  Future<void> zeroX() async => throw StateError('Receipt must never zero X');
  @override
  Future<void> dispose() async {
    connected = false;
    board.clients.remove(this);
    await _statuses.close();
    await _positions.close();
  }
}
