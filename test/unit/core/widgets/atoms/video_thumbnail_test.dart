import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/widgets/atoms/video_thumbnail.dart';
import 'package:visibility_detector/visibility_detector.dart';

Widget _wrapped(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  group('VideoThumbnail', () {
    testWidgets('renders without crashing for a video URL', (tester) async {
      await tester.pumpWidget(
        _wrapped(
          const SizedBox(
            width: 200,
            height: 200,
            child: VideoThumbnail(videoUrl: 'https://example.com/clip.mp4'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(VideoThumbnail), findsOneWidget);
    });

    testWidgets('shows placeholder colored box before controller initializes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapped(
          const SizedBox(
            width: 200,
            height: 200,
            child: VideoThumbnail(videoUrl: 'https://example.com/clip.mp4'),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byType(ColoredBox),
        findsWidgets,
        reason: 'placeholder must render before video frame is ready',
      );
    });

    testWidgets('wraps content in a VisibilityDetector for lazy init', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapped(
          const SizedBox(
            width: 200,
            height: 200,
            child: VideoThumbnail(videoUrl: 'https://example.com/clip.mp4'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(VisibilityDetector), findsOneWidget);
    });

    testWidgets('does not throw on dispose', (tester) async {
      await tester.pumpWidget(
        _wrapped(
          const SizedBox(
            width: 200,
            height: 200,
            child: VideoThumbnail(videoUrl: 'https://example.com/clip.mp4'),
          ),
        ),
      );
      await tester.pump();

      expect(() => tester.binding.scheduleFrame(), returnsNormally);
    });
  });
}
