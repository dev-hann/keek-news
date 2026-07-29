import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/themes/app_schemes.dart';

void main() {
  group('AppSchemes', () {
    test('orange should have name Orange', () {
      expect(AppSchemes.orange.name, 'Orange');
    });

    test('orange should have description', () {
      expect(AppSchemes.orange.description, isNotEmpty);
    });

    test('orange light primary should be non-null', () {
      expect(AppSchemes.orange.light.primary, isNotNull);
    });

    test('orange dark primary should be non-null', () {
      expect(AppSchemes.orange.dark.primary, isNotNull);
    });

    test('orange light and dark should have different primary', () {
      expect(
        AppSchemes.orange.light.primary,
        isNot(equals(AppSchemes.orange.dark.primary)),
      );
    });
  });
}
