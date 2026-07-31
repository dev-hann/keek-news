import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/const/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('dark should return ThemeData with Material 3', () {
      final theme = AppTheme.dark();
      expect(theme.useMaterial3, isTrue);
    });

    test('dark should have non-null colorScheme', () {
      final theme = AppTheme.dark();
      expect(theme.colorScheme, isNotNull);
    });

    test('dark should have non-null textTheme', () {
      final theme = AppTheme.dark();
      expect(theme.textTheme, isNotNull);
    });

    test('dark brightness should be dark', () {
      final theme = AppTheme.dark();
      expect(theme.brightness, Brightness.dark);
    });

    test('typography should have bodyLarge with height 1.6', () {
      final theme = AppTheme.dark();
      expect(theme.textTheme.bodyLarge?.height, 1.6);
    });

    test('typography should have bodyMedium with height 1.5', () {
      final theme = AppTheme.dark();
      expect(theme.textTheme.bodyMedium?.height, 1.5);
    });

    test('typography should have non-negative letter spacing', () {
      final theme = AppTheme.dark();
      final styles = [
        theme.textTheme.headlineLarge,
        theme.textTheme.headlineMedium,
        theme.textTheme.titleLarge,
        theme.textTheme.titleMedium,
        theme.textTheme.bodyLarge,
        theme.textTheme.bodyMedium,
        theme.textTheme.bodySmall,
      ];
      for (final style in styles) {
        expect(
          style?.letterSpacing ?? 0,
          greaterThanOrEqualTo(0),
          reason: '$style has negative letter spacing',
        );
      }
    });
  });
}
