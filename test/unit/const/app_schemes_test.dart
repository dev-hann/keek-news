import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/const/app_schemes.dart';

void main() {
  group('AppSchemes', () {
    test('orange dark primary should be non-null', () {
      expect(AppSchemes.orange.primary, isNotNull);
    });

    test('orange dark primaryContainer should be non-null', () {
      expect(AppSchemes.orange.primaryContainer, isNotNull);
    });

    test('orange dark secondary should be non-null', () {
      expect(AppSchemes.orange.secondary, isNotNull);
    });
  });
}
