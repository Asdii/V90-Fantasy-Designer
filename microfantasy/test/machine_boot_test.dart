import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/app/app_controller.dart';
import 'package:microfantasy/models/app_settings.dart';
import 'package:microfantasy/repositories/key_value_store.dart';
import 'package:microfantasy/repositories/machine_boot_repository.dart';
import 'package:microfantasy/repositories/settings_repository.dart';
import 'package:microfantasy/services/fantasy_designer/local_receiver_service.dart';
import 'support/boot_machine.dart';

Future<void> settleBoot(AppController c) async {
  await Future<void>.delayed(const Duration(milliseconds: 10));
  await c.flush();
}

Future<AppController> openPhone(KeyValueStore store, BootMachine board) async {
  final c = AppController(
    store: store,
    designer: LocalReceiverService(port: 0, bindAddress: '127.0.0.1'),
    hardwareFactory: (_) => board.client(),
  );
  await c.initialize();
  await settleBoot(c);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<void> configure(KeyValueStore store) => SettingsRepository(
    store,
  ).save(AppSettings(simulation: false, haptics: false));

  test(
    'board waits for phone; durable unread notice survives closing the app after ACK',
    () async {
      final store = MemoryStore();
      final board = BootMachine();
      await configure(store);
      board.restart(); // App was closed during power-up.
      expect(board.pending, true);
      board.beforeReceipt = () async {
        final record = (await MachineBootRepository(store).load()).single;
        expect(record.bootId, board.bootId);
        expect(record.unread, true);
      };
      final first = await openPhone(store, board);
      expect(first.pendingBootNotice!.bootId, 'boot-2');
      expect(board.pending, false);
      expect(board.receipts, 1);
      first.dispose();
      final next = await openPhone(store, board);
      addTearDown(next.dispose);
      expect(next.pendingBootNotice!.bootId, 'boot-2');
      expect(board.receipts, 1);
      await next.dismissBootNotice();
      expect(next.pendingBootNotice, isNull);
      await next.reconnectMachine();
      await settleBoot(next);
      expect(next.pendingBootNotice, isNull);
      expect(board.receipts, 1);
      board.restart();
      await settleBoot(next);
      expect(next.pendingBootNotice!.bootId, 'boot-3');
      expect(board.receipts, 2);
      expect(next.xAxisReady, false); // Acknowledging is not an axis reference.
    },
  );

  test(
    'temporary Wi-Fi loss preserves X and does not announce another restart',
    () async {
      final store = MemoryStore();
      final board = BootMachine();
      await configure(store);
      final c = await openPhone(store, board);
      addTearDown(c.dispose);
      await c.dismissBootNotice();
      await c.foreground(false);
      board.x = 25.5; // The board keeps counting while disconnected.
      await c.foreground(true);
      await settleBoot(c);
      expect(c.rawX, 25.5);
      expect(c.pendingBootNotice, isNull);
      expect(board.receipts, 1);
    },
  );

  test(
    'storage failure never ACKs; successful retry persists and delivers notice',
    () async {
      final store = _FailingStore();
      final board = BootMachine();
      await configure(store);
      final c = await openPhone(store, board);
      addTearDown(c.dispose);
      expect(board.pending, true);
      expect(board.receipts, 0);
      store.failBootWrite = false;
      await Future<void>.delayed(const Duration(milliseconds: 2100));
      board.broadcast();
      await settleBoot(c);
      expect(board.pending, false);
      expect(c.pendingBootNotice, isNotNull);
    },
  );

  test('lost ACK is retried without resurrecting a dismissed notice', () async {
    final store = MemoryStore();
    final board = BootMachine()..dropReceipt = true;
    await configure(store);
    final c = await openPhone(store, board);
    addTearDown(c.dispose);
    expect(board.pending, true);
    await c.dismissBootNotice();
    board.dropReceipt = false;
    await Future<void>.delayed(const Duration(milliseconds: 2100));
    board.broadcast();
    await settleBoot(c);
    expect(board.receipts, 2);
    expect(board.pending, false);
    expect(c.pendingBootNotice, isNull);
    expect(board.x, 17.25);
  });
}

class _FailingStore extends MemoryStore {
  bool failBootWrite = true;
  @override
  Future<void> setString(String key, String value) async {
    if (failBootWrite && key == 'microfantasy.machine_boots.v1') {
      throw StateError('Disk unavailable');
    }
    await super.setString(key, value);
  }
}
