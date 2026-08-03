import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/video_id.dart';
import 'package:keek_news/widgets/inline_video_player.dart';
import 'package:keek_news/widgets/video_buffering_overlay.dart';
import 'package:keek_news/widgets/video_error_view.dart';
import 'package:keek_news/widgets/video_surface.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

Widget _wrapped(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  group('InlineVideoPlayer', () {
    testWidgets('should show play icon for non-GIF VideoBlock', (tester) async {
      const block = VideoBlock(url: 'https://example.com/video.mp4');
      await tester.pumpWidget(_wrapped(const InlineVideoPlayer(block: block)));
      await tester.pump();
      expect(find.byIcon(LucideIcons.play), findsWidgets);
    });

    testWidgets('should show muted icon by default for VideoBlock', (
      tester,
    ) async {
      const block = VideoBlock(url: 'https://example.com/video.mp4');
      await tester.pumpWidget(_wrapped(const InlineVideoPlayer(block: block)));
      await tester.pump();
      expect(find.byIcon(LucideIcons.volumeX), findsOneWidget);
    });

    testWidgets('should show fullscreen icon for VideoBlock', (tester) async {
      const block = VideoBlock(url: 'https://example.com/video.mp4');
      await tester.pumpWidget(_wrapped(const InlineVideoPlayer(block: block)));
      await tester.pump();
      expect(find.byIcon(LucideIcons.maximize), findsOneWidget);
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
      expect(find.byIcon(LucideIcons.volumeX), findsNothing);
      expect(find.byIcon(LucideIcons.maximize), findsNothing);
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
        expect(find.byIcon(LucideIcons.play), findsOneWidget);
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
        expect(find.byIcon(LucideIcons.maximize), findsOneWidget);
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

    testWidgets('shows VideoErrorView with retry affordance when init fails', (
      tester,
    ) async {
      const block = VideoBlock(url: 'https://example.com/bad.mp4');
      await tester.pumpWidget(_wrapped(const InlineVideoPlayer(block: block)));
      await tester.pumpAndSettle();
      expect(find.byType(VideoErrorView), findsOneWidget);
      expect(find.text('동영상을 불러올 수 없습니다'), findsOneWidget);
      expect(find.text('탭하여 재시도'), findsOneWidget);
    });

    testWidgets(
      'tapping the error view does not crash and re-enters a recoverable state',
      (tester) async {
        const block = VideoBlock(url: 'https://example.com/bad.mp4');
        await tester.pumpWidget(
          _wrapped(const InlineVideoPlayer(block: block)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(VideoErrorView), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(InlineVideoPlayer), findsOneWidget);
        expect(find.byType(VideoErrorView), findsOneWidget);
      },
    );

    testWidgets(
      'mounts a VideoBufferingOverlay so the buffering state has a UI slot',
      (tester) async {
        const block = VideoBlock(url: 'https://example.com/v.mp4');
        await tester.pumpWidget(
          _wrapped(const InlineVideoPlayer(block: block)),
        );
        await tester.pump();
        expect(find.byType(VideoBufferingOverlay), findsOneWidget);
      },
    );
  });
}
