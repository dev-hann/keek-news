import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/providers/feed_video_playback_provider.dart';
import 'package:happy_news/core/widgets/atoms/video_surface.dart';
import 'package:happy_news/core/widgets/molecules/inline_video_player.dart';
import 'package:happy_news/domain/entities/content_block.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

Widget _wrapped(Widget child) => ProviderScope(
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  group('InlineVideoPlayer', () {
    testWidgets('should show play icon for non-GIF VideoBlock', (tester) async {
      const block = VideoBlock(url: 'https://example.com/video.mp4');
      await tester.pumpWidget(_wrapped(const InlineVideoPlayer(block: block)));
      await tester.pump();
      expect(find.byIcon(Icons.play_arrow), findsWidgets);
    });

    testWidgets('should show muted icon by default for VideoBlock', (
      tester,
    ) async {
      const block = VideoBlock(url: 'https://example.com/video.mp4');
      await tester.pumpWidget(_wrapped(const InlineVideoPlayer(block: block)));
      await tester.pump();
      expect(find.byIcon(Icons.volume_off), findsOneWidget);
    });

    testWidgets('should show fullscreen icon for VideoBlock', (tester) async {
      const block = VideoBlock(url: 'https://example.com/video.mp4');
      await tester.pumpWidget(_wrapped(const InlineVideoPlayer(block: block)));
      await tester.pump();
      expect(find.byIcon(Icons.fullscreen), findsOneWidget);
    });

    testWidgets('should show time display for VideoBlock', (tester) async {
      const block = VideoBlock(url: 'https://example.com/video.mp4');
      await tester.pumpWidget(_wrapped(const InlineVideoPlayer(block: block)));
      await tester.pump();
      expect(find.text('0:00 / 0:00'), findsOneWidget);
    });

    testWidgets('should not show control bar for isGifConversion VideoBlock', (
      tester,
    ) async {
      const block = VideoBlock(
        url: 'https://example.com/clip.mp4',
        isGifConversion: true,
      );
      await tester.pumpWidget(_wrapped(const InlineVideoPlayer(block: block)));
      await tester.pump();
      expect(find.byIcon(Icons.volume_off), findsNothing);
      expect(find.byIcon(Icons.fullscreen), findsNothing);
      expect(find.text('0:00 / 0:00'), findsNothing);
    });

    testWidgets(
      'should show center play button for isGifConversion VideoBlock',
      (tester) async {
        const block = VideoBlock(
          url: 'https://example.com/clip.mp4',
          isGifConversion: true,
        );
        await tester.pumpWidget(
          _wrapped(const InlineVideoPlayer(block: block)),
        );
        await tester.pump();
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      },
    );

    testWidgets(
      'should accept autoplay and videoId without breaking rendering',
      (tester) async {
        const block = VideoBlock(url: 'https://example.com/video.mp4');
        await tester.pumpWidget(
          _wrapped(
            const InlineVideoPlayer(
              block: block,
              autoplay: true,
              videoId: VideoId(postId: 1, blockIndex: 0),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(InlineVideoPlayer), findsOneWidget);
        expect(find.byIcon(Icons.fullscreen), findsOneWidget);
      },
    );

    testWidgets(
      'video surface should fit contain so original content is never cropped',
      (tester) async {
        final controller = VideoPlayerController.networkUrl(
          Uri.parse('https://example.com/video.mp4'),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: VideoSurface(controller: controller)),
          ),
        );
        await tester.pump();

        final fitted = tester.widget<FittedBox>(find.byType(FittedBox));
        expect(
          fitted.fit,
          BoxFit.contain,
          reason: 'video must use contain, never cover, to avoid cropping',
        );
      },
    );
  });
}
