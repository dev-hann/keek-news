import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/comment.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/widgets/comment_tile.dart';
import 'package:keek_news/widgets/retryable_network_image.dart';
import 'package:keek_news/widgets/video_thumbnail.dart';
import 'package:visibility_detector/visibility_detector.dart';

Comment _comment({
  String author = '작성자',
  String content = '본문 내용',
  int recommendCount = 0,
  bool isBest = false,
  List<ContentBlock> mediaBlocks = const [],
  List<Comment> replies = const [],
}) {
  return Comment(
    id: 1,
    author: author,
    content: content,
    date: DateTime(2026, 7, 27, 19, 39),
    recommendCount: recommendCount,
    isBest: isBest,
    replies: replies,
    mediaBlocks: mediaBlocks,
  );
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  group('CommentTile', () {
    testWidgets('renders author and content', (tester) async {
      await tester.pumpWidget(
        _wrap(SingleChildScrollView(child: CommentTile(comment: _comment()))),
      );

      expect(find.text('작성자'), findsOneWidget);
      expect(find.text('본문 내용'), findsOneWidget);
    });

    testWidgets('shows best badge and recommend count when present', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: CommentTile(
              comment: _comment(isBest: true, recommendCount: 12),
            ),
          ),
        ),
      );

      expect(find.text('베스트'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('renders image thumbnail when comment has media', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: CommentTile(
              comment: _comment(
                mediaBlocks: const [
                  ImageBlock(url: 'https://example.com/a.png'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(RetryableNetworkImage), findsOneWidget);
    });

    testWidgets('renders VideoBlock as a tappable video thumbnail', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: CommentTile(
              comment: _comment(
                mediaBlocks: const [
                  VideoBlock(url: 'https://example.com/c.mp4'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(VideoThumbnail), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
    });

    testWidgets('renders nested replies', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: CommentTile(
              comment: _comment(
                content: '부모 댓글',
                replies: [_comment(author: '대댓글러', content: '대댓글 내용')],
              ),
            ),
          ),
        ),
      );

      expect(find.text('부모 댓글'), findsOneWidget);
      expect(find.text('대댓글러'), findsOneWidget);
      expect(find.text('대댓글 내용'), findsOneWidget);
      // Two CommentTiles: parent + reply.
      expect(find.byType(CommentTile), findsNWidgets(2));
    });
  });
}
