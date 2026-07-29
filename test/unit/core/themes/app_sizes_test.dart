import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/themes/app_sizes.dart';

void main() {
  group('AppSizes', () {
    test('minTouchTarget should be 44', () {
      expect(AppSizes.minTouchTarget, 44);
    });

    test('thumbnail small should be 48', () {
      expect(AppSizes.thumbnailSmall, 48);
    });

    test('thumbnail medium should be 72', () {
      expect(AppSizes.thumbnailMedium, 72);
    });

    test('thumbnail large should be 120', () {
      expect(AppSizes.thumbnailLarge, 120);
    });

    test('screenHPadding should be 16', () {
      expect(AppSizes.screenHPadding, 16);
    });

    test('thumbnail sizes should be ordered small < medium < large', () {
      expect(AppSizes.thumbnailSmall < AppSizes.thumbnailMedium, isTrue);
      expect(AppSizes.thumbnailMedium < AppSizes.thumbnailLarge, isTrue);
    });

    test('minTouchTarget should be at least 44', () {
      expect(AppSizes.minTouchTarget, greaterThanOrEqualTo(44));
    });

    test('feedMediaMinHeight should be 420', () {
      expect(AppSizes.feedMediaMinHeight, 420);
    });

    test('feedMediaMaxHeight should be 600', () {
      expect(AppSizes.feedMediaMaxHeight, 600);
    });

    test('feedMediaHeightRatio should be 0.66', () {
      expect(AppSizes.feedMediaHeightRatio, 0.66);
    });

    test(
      'feedMediaHeight should floor at feedMediaMinHeight on short screens',
      () {
        expect(AppSizes.feedMediaHeight(400), AppSizes.feedMediaMinHeight);
      },
    );

    test(
      'feedMediaHeight should cap at feedMediaMaxHeight on tall screens',
      () {
        expect(AppSizes.feedMediaHeight(2000), AppSizes.feedMediaMaxHeight);
      },
    );

    test('feedMediaHeight should be 0.66 of screen height for mid sizes', () {
      expect(AppSizes.feedMediaHeight(800), closeTo(528, 0.01));
    });
  });
}
