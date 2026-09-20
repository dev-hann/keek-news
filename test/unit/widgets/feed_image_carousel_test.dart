import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/widgets/feed_image_carousel.dart';
import 'package:keek_news/widgets/video_thumbnail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../helpers/media_action_fakes.dart';
import '../../helpers/shad_harness.dart';

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDown(GetIt.I.reset);

  group('FeedImageCarousel', () {
    testWidgets('single image shows no indicator', (tester) async {
      await tester.pumpWidget(
        shadHarness(
          const FeedImageCarousel(
            imageUrls: ['https://example.com/a.jpg'],
            postId: 1,
          ),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('1/1'), findsNothing);
    });

    testWidgets('multiple images show "1/N" indicator', (tester) async {
      await tester.pumpWidget(
        shadHarness(
          const FeedImageCarousel(imageUrls: ['a', 'b', 'c'], postId: 1),
        ),
      );
      expect(find.text('1/3'), findsOneWidget);
    });

    testWidgets('swipe advances the indicator', (tester) async {
      await tester.pumpWidget(
        shadHarness(const FeedImageCarousel(imageUrls: ['a', 'b'], postId: 1)),
      );
      expect(find.text('1/2'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('2/2'), findsOneWidget);
    });

    testWidgets('tap calls onImageTap with index', (tester) async {
      var tapped = -1;
      await tester.pumpWidget(
        shadHarness(
          FeedImageCarousel(
            imageUrls: const ['a', 'b'],
            postId: 1,
            onImageTap: (i) => tapped = i,
          ),
        ),
      );
      await tester.tap(find.byType(FeedImageCarousel));
      expect(tapped, 0);
    });

    testWidgets('page indicator is positioned at the top of the carousel', (
      tester,
    ) async {
      await tester.pumpWidget(
        shadHarness(const FeedImageCarousel(imageUrls: ['a', 'b'], postId: 1)),
      );
      final badgeCenter = tester.getCenter(find.text('1/2'));
      final carouselCenter = tester.getCenter(find.byType(FeedImageCarousel));
      expect(
        badgeCenter.dy,
        lessThan(carouselCenter.dy),
        reason: 'indicator should sit at the top, away from video controls',
      );
    });

    testWidgets('video block without thumbnail renders VideoThumbnail '
        '(local frame fallback)', (tester) async {
      const block = VideoBlock(url: 'https://example.com/nthumb.mp4');
      await tester.pumpWidget(
        shadHarness(
          const FeedImageCarousel(
            imageUrls: [],
            videoBlocks: [block],
            postId: 9,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byType(VideoThumbnail),
        findsOneWidget,
        reason:
            'null-thumbnail videos must use VideoThumbnail for local '
            'frame extraction',
      );
    });

    testWidgets('long-press on an image opens the media action sheet', (
      tester,
    ) async {
      final repo = StubMediaSaveRepo();
      registerMediaActionFakes(repo);
      await tester.pumpWidget(
        shadHarness(
          const FeedImageCarousel(
            imageUrls: ['https://example.com/a.jpg'],
            postId: 1,
          ),
        ),
      );
      await tester.pump();

      await tester.longPress(find.byType(PageView));
      await tester.pumpAndSettle();

      expect(find.text('갤러리에 저장'), findsOneWidget);
      expect(repo.savedImages, isEmpty);
    });

    testWidgets('long-press on a video thumbnail opens the sheet '
        'for the video target', (tester) async {
      final repo = StubMediaSaveRepo();
      registerMediaActionFakes(repo);
      const block = VideoBlock(url: 'https://example.com/v.mp4');
      await tester.pumpWidget(
        shadHarness(
          const FeedImageCarousel(
            imageUrls: [],
            videoBlocks: [block],
            postId: 2,
          ),
        ),
      );
      await tester.pump();

      await tester.longPress(find.byType(PageView));
      await tester.pumpAndSettle();

      expect(find.text('갤러리에 저장'), findsOneWidget);
      expect(find.byIcon(LucideIcons.download), findsOneWidget);
    });
  });
}
