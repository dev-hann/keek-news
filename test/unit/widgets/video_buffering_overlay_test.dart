import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/widgets/video_buffering_overlay.dart';

Widget _wrapped(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('VideoBufferingOverlay', () {
    testWidgets('renders nothing when visible is false', (tester) async {
      await tester.pumpWidget(
        _wrapped(const VideoBufferingOverlay(visible: false)),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(VideoBufferingOverlay), findsOneWidget);
    });

    testWidgets('renders spinner when visible is true', (tester) async {
      await tester.pumpWidget(
        _wrapped(const VideoBufferingOverlay(visible: true)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('does not absorb taps so underlying controls stay usable', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrapped(
          Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const SizedBox.expand(),
              ),
              const VideoBufferingOverlay(visible: true),
            ],
          ),
        ),
      );
      await tester.tap(find.byType(VideoBufferingOverlay), warnIfMissed: false);
      expect(taps, 1, reason: 'overlay must let taps pass through to controls');
    });
  });
}
