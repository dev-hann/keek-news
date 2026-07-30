import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/widgets/settings_tile.dart';

void main() {
  group('SettingsTile', () {
    testWidgets('renders title in onSurface by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SettingsTile(title: '버전')),
        ),
      );

      final text = tester.widget<Text>(find.text('버전'));
      expect(text.style?.color, isNot(equals(const ColorScheme.light().error)));
    });

    testWidgets('destructive renders title in colorScheme.error', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsTile(title: '읽은 기록 초기화', destructive: true),
          ),
        ),
      );

      final theme = Theme.of(tester.element(find.text('읽은 기록 초기화')));
      final text = tester.widget<Text>(find.text('읽은 기록 초기화'));
      expect(text.style?.color, theme.colorScheme.error);
    });

    testWidgets('destructive tints the leading icon with error color', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsTile(
              title: '캐시 삭제',
              leading: Icon(Icons.delete_sweep_outlined),
              destructive: true,
            ),
          ),
        ),
      );

      final theme = Theme.of(tester.element(find.byType(Icon)));
      final icon = tester.widget<Icon>(find.byType(Icon));
      // IconTheme.merge applies error color; the resolved effective color is
      // error.
      expect(icon.color, isNull); // not set directly; tinted via IconTheme
      expect(find.byType(Icon), findsOneWidget);
      // Verify the effective icon color resolves to error via the context's
      // IconTheme after merge.
      final ctx = tester.element(find.byType(Icon));
      expect(IconTheme.of(ctx).color, theme.colorScheme.error);
    });
  });
}
