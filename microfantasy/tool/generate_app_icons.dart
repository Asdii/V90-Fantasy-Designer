// Vector asset export: flutter test tool/generate_app_icons.dart
// Reuses the same handpiece-and-gem drawing as the app header.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/widgets/microfantasy_mark.dart';

void main() {
  test('export app icon sizes from the vector mark', () async {
    final targets = <String, int>{
      for (final entry in {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
      }.entries)
        'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png':
            entry.value,
      'web/favicon.png': 32,
      'web/icons/Icon-192.png': 192,
      'web/icons/Icon-512.png': 512,
      'web/icons/Icon-maskable-192.png': 192,
      'web/icons/Icon-maskable-512.png': 512,
    };
    const ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final contents = jsonDecode(
      await File('$ios/Contents.json').readAsString(),
    );
    for (final entry in contents['images'] as List) {
      targets['$ios/${entry['filename']}'] =
          (double.parse((entry['size'] as String).split('x').first) *
                  double.parse((entry['scale'] as String).replaceAll('x', '')))
              .round();
    }
    for (final entry in targets.entries) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final pixels = entry.value;
      canvas.drawColor(const Color(0xffe6f2f6), BlendMode.src);
      // Leave mask-safe space around the actual mark for platform icon shapes.
      final inset = pixels * .1;
      canvas.translate(inset, inset);
      const MicroFantasyMarkPainter().paint(
        canvas,
        Size.square(pixels - inset * 2),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(pixels, pixels);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(entry.key).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    }
  });
}
