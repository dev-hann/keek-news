import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/const/app_sizes.dart';
import 'package:keek_news/widgets/skeleton_box.dart';
import 'package:keek_news/widgets/skeleton_feed_card.dart';

void main() {
  group('SkeletonFeedCard', () {
    testWidgets('renders multiple SkeletonBox widgets', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SkeletonFeedCard())),
      );

      expect(find.byType(SkeletonBox), findsNWidgets(10));
    });

    testWidgets('media-block SkeletonBox height equals feedMediaHeight(600)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SkeletonFeedCard())),
      );

      final boxes = tester.widgetList<SkeletonBox>(find.byType(SkeletonBox));
      final mediaHeights = boxes
          .where((b) => b.width == double.infinity)
          .map((b) => b.height)
          .toList();
      expect(mediaHeights, contains(AppSizes.feedMediaHeight(600)));
    });

    testWidgets(
      'accepts custom screenHeight and reflects it in the media box',
      (tester) async {
        tester.view.physicalSize = const Size(800, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: SkeletonFeedCard(screenHeight: 800)),
          ),
        );

        final boxes = tester.widgetList<SkeletonBox>(find.byType(SkeletonBox));
        final mediaHeights = boxes
            .where((b) => b.width == double.infinity)
            .map((b) => b.height)
            .toList();
        expect(mediaHeights, contains(AppSizes.feedMediaHeight(800)));
      },
    );
  });
}
