import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/widgets/media_count_badge.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../helpers/shad_harness.dart';

void main() {
  group('MediaCountBadge', () {
    testWidgets('renders provided text', (tester) async {
      await tester.pumpWidget(shadHarness(const MediaCountBadge(text: '1/3')));

      expect(find.text('1/3'), findsOneWidget);
    });

    testWidgets('renders ShadBadge primitive', (tester) async {
      await tester.pumpWidget(shadHarness(const MediaCountBadge(text: '1/3')));

      expect(find.byType(ShadBadge), findsOneWidget);
    });

    testWidgets('applies default border radius', (tester) async {
      await tester.pumpWidget(shadHarness(const MediaCountBadge(text: '1/3')));

      final shape = tester.widget<ShadBadge>(find.byType(ShadBadge)).shape!;
      final radius = (shape as RoundedRectangleBorder).borderRadius;
      expect(
        radius as BorderRadius,
        const BorderRadius.all(Radius.circular(12)),
      );
    });

    testWidgets('applies default padding', (tester) async {
      await tester.pumpWidget(shadHarness(const MediaCountBadge(text: '1/3')));

      final badge = tester.widget<ShadBadge>(find.byType(ShadBadge));
      expect(
        badge.padding,
        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      );
    });

    testWidgets('applies overlay background color', (tester) async {
      await tester.pumpWidget(shadHarness(const MediaCountBadge(text: '1/3')));

      final badge = tester.widget<ShadBadge>(find.byType(ShadBadge));
      expect(badge.backgroundColor, const Color(0x8A000000));
    });

    testWidgets('applies overlay foreground color', (tester) async {
      await tester.pumpWidget(shadHarness(const MediaCountBadge(text: '1/3')));

      final badge = tester.widget<ShadBadge>(find.byType(ShadBadge));
      expect(badge.foregroundColor, Colors.white);
    });

    testWidgets('respects custom border radius', (tester) async {
      const custom = BorderRadius.all(Radius.circular(20));
      await tester.pumpWidget(
        shadHarness(const MediaCountBadge(text: '+5', borderRadius: custom)),
      );

      final shape = tester.widget<ShadBadge>(find.byType(ShadBadge)).shape!;
      final radius = (shape as RoundedRectangleBorder).borderRadius;
      expect(radius as BorderRadius, custom);
    });

    testWidgets('respects custom padding', (tester) async {
      const custom = EdgeInsets.all(12);
      await tester.pumpWidget(
        shadHarness(const MediaCountBadge(text: '+5', padding: custom)),
      );

      expect(tester.widget<ShadBadge>(find.byType(ShadBadge)).padding, custom);
    });

    testWidgets('merges custom style with overlay foreground + bold', (
      tester,
    ) async {
      const customStyle = TextStyle(fontSize: 18, color: Colors.red);
      await tester.pumpWidget(
        shadHarness(const MediaCountBadge(text: '+5', style: customStyle)),
      );

      final text = tester.widget<Text>(find.text('+5'));
      expect(text.style?.fontSize, 18);
      expect(text.style?.color, Colors.white);
      expect(text.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('falls back to labelSmall when style omitted', (tester) async {
      await tester.pumpWidget(shadHarness(const MediaCountBadge(text: '+9')));

      final theme = Theme.of(tester.element(find.byType(MediaCountBadge)));
      final text = tester.widget<Text>(find.text('+9'));
      expect(text.style?.fontWeight, FontWeight.w700);
      expect(text.style?.color, Colors.white);
      expect(text.style?.fontSize, theme.textTheme.labelSmall?.fontSize);
    });
  });
}
