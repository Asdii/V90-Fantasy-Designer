// Manual browser-to-native receiver check; binds only to this computer.
// dart run tool/receiver_probe.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:microfantasy/services/fantasy_designer/local_receiver_service.dart';

Future<void> main() async {
  final receiver = LocalReceiverService(
    bindAddress: '127.0.0.1',
    allowBrowserPairing: true,
  );
  await receiver.start();
  stdout.writeln('Local test receiver: ${receiver.endpoints.single}');
  stdout.writeln('Temporary test pairing code: ${receiver.pairingToken}');
  final done = Completer<void>();
  final subscription = receiver.pendingJobs.listen((job) async {
    final file = File('build/qa/browser-received-job.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(job.toJson()),
    );
    stdout.writeln(
      'Received ${job.steps.length} steps; Cut Helper v${job.cutHelper == null ? 0 : 1}. Saved ${file.path}',
    );
    if (!done.isCompleted) done.complete();
  });
  try {
    await done.future.timeout(const Duration(minutes: 10));
    // Let the HTTP acceptance response reach the browser before closing.
    await Future<void>.delayed(const Duration(seconds: 2));
  } finally {
    await subscription.cancel();
    await receiver.dispose();
  }
}
