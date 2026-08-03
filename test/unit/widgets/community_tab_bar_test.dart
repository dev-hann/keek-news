import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/widgets/community_tab_bar.dart';

import '../../helpers/shad_harness.dart';

void main() {
  group('CommunityTabBar', () {
    testWidgets('renders a chip for each community shortName', (tester) async {
      await tester.pumpWidget(
        shadHarness(
          SizedBox(
            width: 400,
            child: CommunityTabBar(
              communities: communities,
              selectedIndex: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      for (final c in communities) {
        expect(find.text(c.shortName), findsOneWidget);
      }
    });

    testWidgets('chips are laid out with equal width (Expanded)', (
      tester,
    ) async {
      await tester.pumpWidget(
        shadHarness(
          SizedBox(
            width: 400,
            child: CommunityTabBar(
              communities: communities,
              selectedIndex: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final boxes = tester.widgetList<Expanded>(find.byType(Expanded)).toList();
      expect(boxes.length, communities.length);
      // All Expanded flex values equal (defaults to 1).
      for (final b in boxes) {
        expect(b.flex, 1);
      }
    });

    testWidgets('tapping a chip calls onChanged with its index', (
      tester,
    ) async {
      final tapped = [-1];
      await tester.pumpWidget(
        shadHarness(
          SizedBox(
            width: 400,
            child: CommunityTabBar(
              communities: communities,
              selectedIndex: 0,
              onChanged: (i) => tapped[0] = i,
            ),
          ),
        ),
      );

      await tester.tap(find.text(communities[2].shortName));
      expect(tapped[0], 2);
    });

    testWidgets('selected chip text uses brand color', (tester) async {
      await tester.pumpWidget(
        shadHarness(
          SizedBox(
            width: 400,
            child: CommunityTabBar(
              communities: communities,
              selectedIndex: 1,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final selectedText = tester.widget<Text>(
        find.text(communities[1].shortName),
      );
      expect(selectedText.style?.color, Color(communities[1].brandColorArgb));
      expect(selectedText.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('inactive chip text uses mutedForeground', (tester) async {
      await tester.pumpWidget(
        shadHarness(
          SizedBox(
            width: 400,
            child: CommunityTabBar(
              communities: communities,
              selectedIndex: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      // communities[1] is not selected (0 is).
      final inactiveText = tester.widget<Text>(
        find.text(communities[1].shortName),
      );
      // Color should not be the brand color.
      expect(
        inactiveText.style?.color,
        isNot(Color(communities[1].brandColorArgb)),
      );
      expect(inactiveText.style?.fontWeight, FontWeight.w400);
    });

    testWidgets('chip wraps text with Semantics using displayName', (
      tester,
    ) async {
      await tester.pumpWidget(
        shadHarness(
          SizedBox(
            width: 400,
            child: CommunityTabBar(
              communities: communities,
              selectedIndex: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final sem = find.ancestor(
        of: find.text(communities[0].shortName),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == communities[0].displayName,
        ),
      );
      expect(sem, findsOneWidget);
    });

    testWidgets('selected chip exposes selected semantics', (tester) async {
      await tester.pumpWidget(
        shadHarness(
          SizedBox(
            width: 400,
            child: CommunityTabBar(
              communities: communities,
              selectedIndex: 2,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final selected = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.selected ?? false) &&
            w.properties.label == communities[2].displayName,
      );
      expect(selected, findsOneWidget);
    });

    testWidgets('enforces 44pt touch target per chip', (tester) async {
      await tester.pumpWidget(
        shadHarness(
          SizedBox(
            width: 400,
            child: CommunityTabBar(
              communities: communities,
              selectedIndex: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      // Each GestureDetector is wrapped in Expanded. The Row has height 44.
      // Verify the bar's height.
      final sizedBox = tester.widget<SizedBox>(
        find
            .ancestor(
              of: find.byType(Row),
              matching: find.byType(SizedBox, skipOffstage: false),
            )
            .first,
      );
      expect(sizedBox.height, 44);
    });
  });
}
