import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/blocked_image.dart';
import 'package:keek_news/widgets/blocked_image_tile.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../helpers/shad_harness.dart';

void main() {
  group('BlockedImageTile', () {
    testWidgets('renders thumbnail, blocked-at time and unblock action', (
      tester,
    ) async {
      await tester.pumpWidget(
        shadHarness(
          Scaffold(
            body: BlockedImageTile(
              image: BlockedImage(
                url: 'https://example.com/a.jpg',
                blockedAt: DateTime.now(),
              ),
              onUnblock: () {},
            ),
          ),
        ),
      );

      expect(find.text('방금 전'), findsOneWidget);
      expect(find.text('https://example.com/a.jpg'), findsOneWidget);
      expect(find.byIcon(LucideIcons.rotateCcw), findsOneWidget);
      expect(find.bySemanticsLabel('차단 해제'), findsOneWidget);
    });

    testWidgets('calls onUnblock when the action is tapped', (tester) async {
      var unblocked = false;
      await tester.pumpWidget(
        shadHarness(
          Scaffold(
            body: BlockedImageTile(
              image: BlockedImage(
                url: 'https://example.com/a.jpg',
                blockedAt: DateTime.now(),
              ),
              onUnblock: () => unblocked = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(LucideIcons.rotateCcw));
      await tester.pump();

      expect(unblocked, isTrue);
    });
  });
}
