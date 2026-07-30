import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keek_news/provider/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'themeMode';

enum ThemeModeOption { system, light, dark }

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>(
  (ref) => ThemeNotifier(ref.read(sharedPreferencesProvider)),
);

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier(this._prefs) : super(_read(_prefs)) {
    _option = _modeToOption(state);
  }

  final SharedPreferences _prefs;
  late ThemeModeOption _option;

  static ThemeMode _read(SharedPreferences prefs) {
    final index = prefs.getInt(_themeModeKey);
    if (index == null || index < 0 || index >= ThemeMode.values.length) {
      return ThemeMode.system;
    }
    return ThemeMode.values[index];
  }

  ThemeModeOption get currentOption => _option;

  void setThemeMode(ThemeModeOption option) {
    _option = option;
    state = _optionToMode(option);
    _prefs.setInt(_themeModeKey, state.index);
  }

  static ThemeMode _optionToMode(ThemeModeOption option) {
    switch (option) {
      case ThemeModeOption.system:
        return ThemeMode.system;
      case ThemeModeOption.light:
        return ThemeMode.light;
      case ThemeModeOption.dark:
        return ThemeMode.dark;
    }
  }

  static ThemeModeOption _modeToOption(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return ThemeModeOption.system;
      case ThemeMode.light:
        return ThemeModeOption.light;
      case ThemeMode.dark:
        return ThemeModeOption.dark;
    }
  }
}
