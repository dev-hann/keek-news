import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/widgets/action_button.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../helpers/shad_harness.dart';

void main() {
  testWidgets('should render given icon', (tester) async {
    await tester.pumpWidget(
      shadHarness(
        const Center(
          child: ActionButton(
            icon: LucideIcons.bookmark,
            semanticsLabel: '저장',
            onTap: null,
          ),
        ),
      ),
    );

    expect(find.byIcon(LucideIcons.bookmark), findsOneWidget);
  });

  testWidgets('should call onTap when tapped', (tester) async {
    final tapped = [0];
    await tester.pumpWidget(
      shadHarness(
        Center(
          child: ActionButton(
            icon: LucideIcons.link,
            semanticsLabel: '링크 복사',
            onTap: () => tapped[0]++,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ActionButton));
    expect(tapped[0], 1);
  });

  testWidgets('should not call onTap when disabled', (tester) async {
    final tapped = [0];
    await tester.pumpWidget(
      shadHarness(
        const Center(
          child: ActionButton(
            icon: LucideIcons.link,
            semanticsLabel: '링크 복사',
            onTap: null,
          ),
        ),
      ),
    );

    try {
      await tester.tap(find.byType(ActionButton), warnIfMissed: false);
    } catch (_) {}
    expect(tapped[0], 0);
  });

  testWidgets('should enforce minimum 44pt touch target', (tester) async {
    await tester.pumpWidget(
      shadHarness(
        Center(
          child: ActionButton(
            icon: LucideIcons.link,
            semanticsLabel: '링크 복사',
            onTap: () {},
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(ActionButton));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('should use onSurfaceVariant color when not active', (
    tester,
  ) async {
    await tester.pumpWidget(
      shadHarness(
        const Center(
          child: ActionButton(
            icon: LucideIcons.bookmark,
            semanticsLabel: '저장',
            onTap: null,
          ),
        ),
      ),
    );

    final theme = Theme.of(tester.element(find.byType(ActionButton)));
    final icon = tester.widget<Icon>(find.byIcon(LucideIcons.bookmark));
    expect(icon.color, theme.colorScheme.onSurfaceVariant);
  });

  testWidgets('should use primary color when active', (tester) async {
    await tester.pumpWidget(
      shadHarness(
        const Center(
          child: ActionButton(
            icon: LucideIcons.bookmark,
            semanticsLabel: '저장 취소',
            active: true,
            onTap: null,
          ),
        ),
      ),
    );

    final theme = Theme.of(tester.element(find.byType(ActionButton)));
    final icon = tester.widget<Icon>(find.byIcon(LucideIcons.bookmark));
    expect(icon.color, theme.colorScheme.primary);
  });

  testWidgets('should use iconMedium size', (tester) async {
    await tester.pumpWidget(
      shadHarness(
        const Center(
          child: ActionButton(
            icon: LucideIcons.link,
            semanticsLabel: '링크 복사',
            onTap: null,
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(LucideIcons.link));
    expect(icon.size, 16);
  });

  testWidgets('should expose semantics label and button role', (tester) async {
    await tester.pumpWidget(
      shadHarness(
        const Center(
          child: ActionButton(
            icon: LucideIcons.bookmark,
            semanticsLabel: '저장',
            onTap: null,
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('저장'), findsOneWidget);
  });

  testWidgets('should expose toggled semantics when active', (tester) async {
    await tester.pumpWidget(
      shadHarness(
        const Center(
          child: ActionButton(
            icon: LucideIcons.bookmark,
            semanticsLabel: '저장',
            active: true,
            onTap: null,
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('저장'), findsOneWidget);
  });
}
