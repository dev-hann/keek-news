import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/themes/app_sizes.dart';
import 'package:happy_news/core/widgets/atoms/feed_media.dart';

void main() {
  group('FeedMedia', () {
    testWidgets('should show placeholder when imageUrl is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FeedMedia(imageUrl: '')),
        ),
      );

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets('should show image when imageUrl is provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeedMedia(imageUrl: 'https://example.com/test.jpg'),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets(
      'should use feedMediaHeight for the media box on a 600-tall screen',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: FeedMedia(imageUrl: '')),
          ),
        );

        final box = tester.widget<SizedBox>(find.byType(SizedBox).first);
        expect(box.height, AppSizes.feedMediaHeight(600));
      },
    );

    testWidgets('should show +N badge when additionalImageCount > 0', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeedMedia(imageUrl: 'x', additionalImageCount: 3),
          ),
        ),
      );

      expect(find.text('+3'), findsOneWidget);
    });

    testWidgets('should not show +N badge when additionalImageCount is 0', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FeedMedia(imageUrl: 'x')),
        ),
      );

      expect(find.text('+1'), findsNothing);
    });

    testWidgets('should call onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedMedia(
              imageUrl: 'https://example.com/test.jpg',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(FeedMedia));
      expect(tapped, isTrue);
    });
  });
}
