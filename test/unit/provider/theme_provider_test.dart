import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/provider/shared_preferences_provider.dart';
import 'package:keek_news/provider/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('ThemeNotifier', () {
    test('should start with system theme mode', () {
      final container = makeContainer();
      expect(container.read(themeProvider), ThemeMode.system);
    });

    test('should switch to light mode', () {
      final container = makeContainer();
      container
          .read(themeProvider.notifier)
          .setThemeMode(ThemeModeOption.light);
      expect(container.read(themeProvider), ThemeMode.light);
    });

    test('should switch to dark mode', () {
      final container = makeContainer();
      container.read(themeProvider.notifier).setThemeMode(ThemeModeOption.dark);
      expect(container.read(themeProvider), ThemeMode.dark);
    });

    test('should switch back to system mode', () {
      final container = makeContainer();
      container.read(themeProvider.notifier).setThemeMode(ThemeModeOption.dark);
      container
          .read(themeProvider.notifier)
          .setThemeMode(ThemeModeOption.system);
      expect(container.read(themeProvider), ThemeMode.system);
    });

    test('should persist chosen mode across instances', () {
      final container = makeContainer();
      container.read(themeProvider.notifier).setThemeMode(ThemeModeOption.dark);
      container.dispose();

      final next = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(next.dispose);

      expect(next.read(themeProvider), ThemeMode.dark);
    });
  });
}
