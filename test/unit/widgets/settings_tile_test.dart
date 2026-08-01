import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/widgets/settings_tile.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../helpers/shad_harness.dart';

void main() {
  group('SettingsTile', () {
    testWidgets('renders title in foreground by default', (tester) async {
      await tester.pumpWidget(shadHarness(const SettingsTile(title: '버전')));

      final text = tester.widget<Text>(find.text('버전'));
      expect(text.style?.color, isNotNull);
    });

    testWidgets('destructive renders title in colorScheme.error', (
      tester,
    ) async {
      await tester.pumpWidget(
        shadHarness(const SettingsTile(title: '읽은 기록 초기화', destructive: true)),
      );

      final theme = Theme.of(tester.element(find.text('읽은 기록 초기화')));
      final text = tester.widget<Text>(find.text('읽은 기록 초기화'));
      expect(text.style?.color, theme.colorScheme.error);
    });

    testWidgets('destructive tints the leading icon with error color', (
      tester,
    ) async {
      await tester.pumpWidget(
        shadHarness(
          const SettingsTile(
            title: '캐시 삭제',
            leading: Icon(LucideIcons.trash2),
            destructive: true,
          ),
        ),
      );

      expect(find.byType(Icon), findsOneWidget);
      final ctx = tester.element(find.byType(Icon));
      expect(IconTheme.of(ctx).color, Theme.of(ctx).colorScheme.error);
    });
  });
}
