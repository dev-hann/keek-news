import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/service/image_hash_service.dart';

/// Renders a horizontal gradient into PNG bytes at [width]×[height].
Future<Uint8List> _gradientPng(
  int width,
  int height, {
  bool inverted = false,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint()
    ..shader = ui.Gradient.linear(
      ui.Offset.zero,
      ui.Offset(width.toDouble(), 0),
      inverted
          ? const [ui.Color(0xFFFFFFFF), ui.Color(0xFF000000)]
          : const [ui.Color(0xFF000000), ui.Color(0xFFFFFFFF)],
    );
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    paint,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  // dart:ui raster/decode futures complete on real async, not the fake
  // testWidgets clock.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FlutterImageHashService.distance', () {
    test('identical fingerprints have distance 0', () {
      expect(
        FlutterImageHashService.distance(
          '0000000000000000',
          '0000000000000000',
        ),
        0,
      );
    });

    test('counts differing bits', () {
      // 0x3f flips the low 6 bits.
      expect(FlutterImageHashService.distance('0000000000000000', '3f'), 6);
    });

    test('unparseable fingerprints never match', () {
      expect(FlutterImageHashService.distance('zzz', '0000000000000000'), 64);
    });
  });

  group('FlutterImageHashService.dHashFromBytes', () {
    test('is stable across rescales of the same picture', () async {
      final small = await _gradientPng(36, 32);
      final large = await _gradientPng(720, 640);

      final hashSmall = await FlutterImageHashService.dHashFromBytes(small);
      final hashLarge = await FlutterImageHashService.dHashFromBytes(large);

      expect(hashSmall, isNotNull);
      expect(hashLarge, isNotNull);
      expect(
        FlutterImageHashService.distance(hashSmall!, hashLarge!),
        lessThanOrEqualTo(6),
        reason: 'rescaled copies of one picture must fingerprint-match',
      );
    });

    test('separates visually different pictures', () async {
      final normal = await _gradientPng(180, 160);
      final inverted = await _gradientPng(180, 160, inverted: true);

      final hashA = await FlutterImageHashService.dHashFromBytes(normal);
      final hashB = await FlutterImageHashService.dHashFromBytes(inverted);

      expect(
        FlutterImageHashService.distance(hashA!, hashB!),
        greaterThan(6),
        reason: 'opposite gradients must not fingerprint-match',
      );
    });

    test('returns null for undecodable bytes', () async {
      final result = await FlutterImageHashService.dHashFromBytes(
        Uint8List.fromList([1, 2, 3, 4]),
      );
      expect(result, isNull);
    });
  });
}
