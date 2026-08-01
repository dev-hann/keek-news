import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/widgets/skeleton_box.dart';
import 'package:keek_news/widgets/skeleton_feed_card.dart';

import '../../helpers/shad_harness.dart';

double _feedMediaHeight(double screenHeight) {
  const ratio = 0.66;
  const min = 420.0;
  const max = 600.0;
  final h = screenHeight * ratio;
  if (h < min) return min;
  if (h > max) return max;
  return h;
}

void main() {
  group('SkeletonFeedCard', () {
    testWidgets('renders multiple SkeletonBox widgets', (tester) async {
      await tester.pumpWidget(shadHarness(const SkeletonFeedCard()));

      expect(find.byType(SkeletonBox), findsNWidgets(10));
    });

    testWidgets('media-block SkeletonBox height equals feedMediaHeight(600)', (
      tester,
    ) async {
      await tester.pumpWidget(shadHarness(const SkeletonFeedCard()));

      final boxes = tester.widgetList<SkeletonBox>(find.byType(SkeletonBox));
      final mediaHeights = boxes
          .where((b) => b.width == double.infinity)
          .map((b) => b.height)
          .toList();
      expect(mediaHeights, contains(_feedMediaHeight(600)));
    });

    testWidgets(
      'accepts custom screenHeight and reflects it in the media box',
      (tester) async {
        tester.view.physicalSize = const Size(800, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          shadHarness(const SkeletonFeedCard(screenHeight: 800)),
        );

        final boxes = tester.widgetList<SkeletonBox>(find.byType(SkeletonBox));
        final mediaHeights = boxes
            .where((b) => b.width == double.infinity)
            .map((b) => b.height)
            .toList();
        expect(mediaHeights, contains(_feedMediaHeight(800)));
      },
    );
  });
}
