import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/video_id.dart';
import 'package:keek_news/widgets/feed_image_carousel.dart';
import 'package:keek_news/widgets/inline_video_player.dart';
import 'package:keek_news/widgets/video_thumbnail.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  group('FeedImageCarousel', () {
    testWidgets('single image shows no indicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeedImageCarousel(
              imageUrls: ['https://example.com/a.jpg'],
              postId: 1,
            ),
          ),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('1/1'), findsNothing);
    });

    testWidgets('multiple images show "1/N" indicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeedImageCarousel(imageUrls: ['a', 'b', 'c'], postId: 1),
          ),
        ),
      );
      expect(find.text('1/3'), findsOneWidget);
    });

    testWidgets('swipe advances the indicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeedImageCarousel(imageUrls: ['a', 'b'], postId: 1),
          ),
        ),
      );
      expect(find.text('1/2'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('2/2'), findsOneWidget);
    });

    testWidgets('tap calls onImageTap with index', (tester) async {
      var tapped = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedImageCarousel(
              imageUrls: const ['a', 'b'],
              postId: 1,
              onImageTap: (i) => tapped = i,
            ),
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
        const MaterialApp(
          home: Scaffold(
            body: FeedImageCarousel(imageUrls: ['a', 'b'], postId: 1),
          ),
        ),
      );
      final badgeCenter = tester.getCenter(find.text('1/2'));
      final carouselCenter = tester.getCenter(find.byType(FeedImageCarousel));
      expect(
        badgeCenter.dy,
        lessThan(carouselCenter.dy),
        reason: 'indicator should sit at the top, away from video controls',
      );
    });

    testWidgets('page indicator does not overlap video fullscreen button', (
      tester,
    ) async {
      const block = VideoBlock(
        url: 'https://example.com/v.mp4',
        thumbnailUrl: 'https://example.com/t.jpg',
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeedImageCarousel(
              imageUrls: ['img'],
              videoBlocks: [block],
              postId: 1,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.play_arrow).first);
      await tester.pumpAndSettle();

      final badge = find.text('2/2');
      final fullscreen = find.widgetWithIcon(IconButton, Icons.fullscreen);
      expect(badge, findsOneWidget);
      expect(fullscreen, findsOneWidget);

      final badgeRect = tester.getRect(badge);
      final fullscreenRect = tester.getRect(fullscreen);
      expect(
        badgeRect.overlaps(fullscreenRect),
        isFalse,
        reason: 'indicator must not overlap the fullscreen button',
      );
    });

    testWidgets(
      'pressing play button mounts inline player with autoplay and videoId',
      (tester) async {
        const block = VideoBlock(
          url: 'https://example.com/v.mp4',
          thumbnailUrl: 'https://example.com/t.jpg',
        );
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: FeedImageCarousel(
                imageUrls: [],
                videoBlocks: [block],
                postId: 7,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(InlineVideoPlayer), findsNothing);
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);

        await tester.tap(find.byIcon(Icons.play_arrow));
        await tester.pumpAndSettle();

        final player = tester.widget<InlineVideoPlayer>(
          find.byType(InlineVideoPlayer),
        );
        expect(player.autoplay, isTrue);
        expect(player.videoId, const VideoId(postId: 7, blockIndex: 0));
      },
    );

    testWidgets('video block without thumbnail renders VideoThumbnail '
        '(local frame fallback)', (tester) async {
      const block = VideoBlock(url: 'https://example.com/nthumb.mp4');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeedImageCarousel(
              imageUrls: [],
              videoBlocks: [block],
              postId: 9,
            ),
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
  });
}
