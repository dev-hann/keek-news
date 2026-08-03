import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/widgets/video_error_view.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../helpers/shad_harness.dart';

void main() {
  group('VideoErrorView', () {
    testWidgets('renders error icon and message', (tester) async {
      await tester.pumpWidget(shadHarness(const VideoErrorView()));
      expect(find.byIcon(LucideIcons.alertCircle), findsOneWidget);
      expect(find.text('동영상을 불러올 수 없습니다'), findsOneWidget);
    });

    testWidgets('does not show retry hint when onRetry is null', (
      tester,
    ) async {
      await tester.pumpWidget(shadHarness(const VideoErrorView()));
      expect(
        find.text('탭하여 재시도'),
        findsNothing,
        reason: 'null callback must not advertise retry',
      );
    });

    testWidgets('calls onRetry when tapped and callback is provided', (
      tester,
    ) async {
      var retries = 0;
      await tester.pumpWidget(
        shadHarness(VideoErrorView(onRetry: () => retries++)),
      );
      expect(find.text('탭하여 재시도'), findsOneWidget);
      await tester.tap(find.byType(VideoErrorView));
      expect(retries, 1);
    });

    testWidgets('does not crash when tapped without callback', (tester) async {
      await tester.pumpWidget(shadHarness(const VideoErrorView()));
      await tester.tap(find.byType(VideoErrorView));
      await tester.pump();
      expect(find.byType(VideoErrorView), findsOneWidget);
    });
  });
}
