import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/domain/entities/content_block.dart';
import 'package:happy_news/presentation/widgets/content_block_view.dart';

void main() {
  group('ContentBlockView (compact — comment media)', () {
    testWidgets('should render nothing for TextBlock', (tester) async {
      const block = TextBlock('Hello World');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ContentBlockView(block: block, allImageUrls: []),
          ),
        ),
      );

      expect(find.text('Hello World'), findsNothing);
    });

    testWidgets('should render nothing for empty TextBlock', (tester) async {
      const block = TextBlock('');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ContentBlockView(block: block, allImageUrls: []),
          ),
        ),
      );

      expect(find.text(''), findsNothing);
    });

    testWidgets('should render compact image thumbnail for ImageBlock', (
      tester,
    ) async {
      const block = ImageBlock(url: 'https://example.com/test.jpg');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ContentBlockView(
              block: block,
              allImageUrls: ['https://example.com/test.jpg'],
            ),
          ),
        ),
      );

      expect(find.byType(GestureDetector), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('should render compact video thumbnail for VideoBlock', (
      tester,
    ) async {
      const block = VideoBlock(url: 'https://example.com/video.mp4');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ContentBlockView(block: block, allImageUrls: []),
          ),
        ),
      );

      expect(find.byType(GestureDetector), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });
  });
}
