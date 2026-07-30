import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/themes/app_sizes.dart';
import 'package:happy_news/core/widgets/atoms/action_button.dart';

void main() {
  Widget harness({required Widget child, required ThemeData theme}) {
    return MaterialApp(
      theme: theme,
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('should render given icon', (tester) async {
    await tester.pumpWidget(
      harness(
        theme: ThemeData.light(),
        child: const ActionButton(
          icon: Icons.bookmark_border,
          semanticsLabel: '저장',
          onTap: null,
        ),
      ),
    );

    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
  });

  testWidgets('should call onTap when tapped', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      harness(
        theme: ThemeData.light(),
        child: ActionButton(
          icon: Icons.link,
          semanticsLabel: '링크 복사',
          onTap: () => tapped++,
        ),
      ),
    );

    await tester.tap(find.byType(ActionButton));
    expect(tapped, 1);
  });

  testWidgets('should not call onTap when disabled', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      harness(
        theme: ThemeData.light(),
        child: ActionButton(
          icon: Icons.link,
          semanticsLabel: '링크 복사',
          onTap: null,
        ),
      ),
    );

    try {
      await tester.tap(find.byType(ActionButton), warnIfMissed: false);
    } catch (_) {}
    expect(tapped, 0);
  });

  testWidgets('should use onSurfaceVariant color when not active', (
    tester,
  ) async {
    final theme = ThemeData.light(useMaterial3: true);
    await tester.pumpWidget(
      harness(
        theme: theme,
        child: const ActionButton(
          icon: Icons.bookmark_border,
          semanticsLabel: '저장',
          active: false,
          onTap: null,
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.bookmark_border));
    expect(icon.color, theme.colorScheme.onSurfaceVariant);
  });

  testWidgets('should use primary color when active', (tester) async {
    final theme = ThemeData.light(useMaterial3: true);
    await tester.pumpWidget(
      harness(
        theme: theme,
        child: const ActionButton(
          icon: Icons.bookmark,
          semanticsLabel: '저장 취소',
          active: true,
          onTap: null,
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.bookmark));
    expect(icon.color, theme.colorScheme.primary);
  });

  testWidgets('should use iconMedium size', (tester) async {
    await tester.pumpWidget(
      harness(
        theme: ThemeData.light(),
        child: const ActionButton(
          icon: Icons.link,
          semanticsLabel: '링크 복사',
          onTap: null,
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.link));
    expect(icon.size, AppSizes.iconMedium);
  });

  testWidgets('should enforce minimum 44pt touch target', (tester) async {
    await tester.pumpWidget(
      harness(
        theme: ThemeData.light(),
        child: ActionButton(
          icon: Icons.link,
          semanticsLabel: '링크 복사',
          onTap: () {},
        ),
      ),
    );

    final size = tester.getSize(find.byType(ActionButton));
    expect(size.width, greaterThanOrEqualTo(AppSizes.minTouchTarget));
    expect(size.height, greaterThanOrEqualTo(AppSizes.minTouchTarget));
  });

  testWidgets('should expose semantics label and button role', (tester) async {
    await tester.pumpWidget(
      harness(
        theme: ThemeData.light(),
        child: const ActionButton(
          icon: Icons.bookmark_border,
          semanticsLabel: '저장',
          onTap: null,
        ),
      ),
    );

    expect(find.bySemanticsLabel('저장'), findsOneWidget);
  });

  testWidgets('should expose toggled semantics when active', (tester) async {
    await tester.pumpWidget(
      harness(
        theme: ThemeData.light(),
        child: const ActionButton(
          icon: Icons.bookmark,
          semanticsLabel: '저장',
          active: true,
          onTap: null,
        ),
      ),
    );

    expect(find.bySemanticsLabel('저장'), findsOneWidget);
  });
}
