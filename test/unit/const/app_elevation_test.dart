import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/const/app_elevation.dart';

void main() {
  group('AppElevation', () {
    test('level0 should be 0', () {
      expect(AppElevation.level0, 0);
    });

    test('level1 should be 1', () {
      expect(AppElevation.level1, 1);
    });

    test('level2 should be 3', () {
      expect(AppElevation.level2, 3);
    });

    test('level3 should be 6', () {
      expect(AppElevation.level3, 6);
    });

    test('level4 should be 8', () {
      expect(AppElevation.level4, 8);
    });

    test('level5 should be 12', () {
      expect(AppElevation.level5, 12);
    });

    test('levels should be ordered ascending', () {
      expect(AppElevation.level0 < AppElevation.level1, isTrue);
      expect(AppElevation.level1 < AppElevation.level2, isTrue);
      expect(AppElevation.level2 < AppElevation.level3, isTrue);
      expect(AppElevation.level3 < AppElevation.level4, isTrue);
      expect(AppElevation.level4 < AppElevation.level5, isTrue);
    });
  });
}
