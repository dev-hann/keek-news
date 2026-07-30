import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/utils/long_image.dart';

void main() {
  group('LongImage.fitWidthScale', () {
    test('returns null for a normal (non-long) image', () {
      // image 16:9 (1.78) in a 9:16-ish portrait viewport (0.5) -> not long
      expect(
        LongImage.fitWidthScale(imageAspect: 1.78, viewportAspect: 0.5),
        isNull,
      );
    });

    test('returns null when aspects are equal', () {
      expect(
        LongImage.fitWidthScale(imageAspect: 0.5, viewportAspect: 0.5),
        isNull,
      );
    });

    test('returns >1 multiplier for a tall comic', () {
      // image 800x4000 (aspect 0.2) in a 400x800 viewport (aspect 0.5)
      final m = LongImage.fitWidthScale(imageAspect: 0.2, viewportAspect: 0.5);
      expect(m, 2.5);
    });

    test('multiplier equals viewportAspect / imageAspect', () {
      final m = LongImage.fitWidthScale(imageAspect: 0.4, viewportAspect: 0.8);
      expect(m, 2.0);
    });
  });
}
