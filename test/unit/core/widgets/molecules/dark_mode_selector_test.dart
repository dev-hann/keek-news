import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/widgets/molecules/dark_mode_selector.dart';
import 'package:happy_news/presentation/providers/theme_provider.dart';

void main() {
  group('DarkModeSelector', () {
    testWidgets('should display three segments', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DarkModeSelector(currentMode: ThemeMode.system)),
        ),
      );

      expect(find.text('시스템'), findsOneWidget);
      expect(find.text('라이트'), findsOneWidget);
      expect(find.text('다크'), findsOneWidget);
    });

    testWidgets('should highlight system segment when system mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DarkModeSelector(currentMode: ThemeMode.system)),
        ),
      );

      final segments = tester.widgetList<SegmentedButton<ThemeModeOption>>(
        find.byType(SegmentedButton<ThemeModeOption>),
      );
      expect(segments.length, 1);
      expect(segments.first.selected, {ThemeModeOption.system});
    });

    testWidgets('should highlight dark segment when dark mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DarkModeSelector(currentMode: ThemeMode.dark)),
        ),
      );

      final segments = tester.widgetList<SegmentedButton<ThemeModeOption>>(
        find.byType(SegmentedButton<ThemeModeOption>),
      );
      expect(segments.first.selected, {ThemeModeOption.dark});
    });

    testWidgets('should call onChanged when segment tapped', (tester) async {
      ThemeModeOption? selectedMode;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DarkModeSelector(
              currentMode: ThemeMode.system,
              onChanged: (mode) => selectedMode = mode,
            ),
          ),
        ),
      );

      await tester.tap(find.text('다크'));
      expect(selectedMode, ThemeModeOption.dark);
    });
  });
}
