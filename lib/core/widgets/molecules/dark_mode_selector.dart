import 'package:flutter/material.dart';
import 'package:happy_news/presentation/providers/theme_provider.dart';

class DarkModeSelector extends StatelessWidget {
  const DarkModeSelector({
    required this.currentMode,
    super.key,
    this.onChanged,
  });
  final ThemeMode currentMode;
  final ValueChanged<ThemeModeOption>? onChanged;

  ThemeModeOption _currentOption() {
    switch (currentMode) {
      case ThemeMode.system:
        return ThemeModeOption.system;
      case ThemeMode.light:
        return ThemeModeOption.light;
      case ThemeMode.dark:
        return ThemeModeOption.dark;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ThemeModeOption>(
      segments: const [
        ButtonSegment(value: ThemeModeOption.system, label: Text('시스템')),
        ButtonSegment(value: ThemeModeOption.light, label: Text('라이트')),
        ButtonSegment(value: ThemeModeOption.dark, label: Text('다크')),
      ],
      selected: {_currentOption()},
      onSelectionChanged: (selected) {
        onChanged?.call(selected.first);
      },
    );
  }
}
