import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/comment.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/widgets/feed_card.dart';
import 'package:keek_news/widgets/feed_card_entry.dart';
import 'package:keek_news/widgets/feed_image_carousel.dart';

void main() {
  String? clipboardContent;

  setUp(() {
    clipboardContent = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final map = call.arguments as Map?;
            clipboardContent = map?['text'] as String?;
            return null;
          }
          if (call.method == 'Clipboard.getData') {
            return clipboardContent == null ? null : {'text': clipboardContent};
          }
          return null;
        });
  });

  const post = FeedItem(
    community: CommunityId.humoruniv,
    id: '1',
    title: '게시글 제목',
    url: '/board/read.html?table=pds&number=1',
    author: '유머작가',
    recommendCount: 42,
    commentCount: 10,
    viewCount: 500,
  );

  PostDetail detailWith({
    List<String> imageUrls = const [],
    List<Comment> comments = const [],
    List<ContentBlock> blocks = const [],
  }) {
    return PostDetail(
      id: 1,
      title: '게시글 제목',
      author: '유머작가',
      date: DateTime(2026, 5, 15),
      contentHtml: '',
      contentBlocks: blocks,
      imageUrls: imageUrls,
      recommendCount: 42,
      notRecommendCount: 1,
      viewCount: 500,
      commentCount: comments.length,
      comments: comments,
    );
  }

  Future<void> pumpEntry(
    WidgetTester tester, {
    PostDetail? detail,
    bool detailLoading = false,
    bool isBookmarked = false,
    VoidCallback? onBookmarkTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              FeedCardEntry(
                post: post,
                detail: detail,
                detailLoading: detailLoading,
                isBookmarked: isBookmarked,
                onBookmarkTap: onBookmarkTap ?? () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('FeedCardEntry', () {
    testWidgets('should render FeedCard with post metadata', (tester) async {
      await pumpEntry(tester);

      expect(find.byType(FeedCard), findsOneWidget);
      expect(find.text('유머작가'), findsOneWidget);
    });

    testWidgets('should show images when detail has imageUrls', (tester) async {
      await pumpEntry(
        tester,
        detail: detailWith(imageUrls: const ['https://example.com/a.jpg']),
      );

      expect(find.byType(FeedImageCarousel), findsOneWidget);
    });

    testWidgets('should show comment preview when detail has comments', (
      tester,
    ) async {
      await pumpEntry(
        tester,
        detail: detailWith(
          comments: [
            Comment(
              id: 1,
              author: '댓글작성자',
              content: '댓글 내용',
              date: DateTime(2026, 5, 15),
              recommendCount: 0,
              isBest: false,
              replies: const [],
            ),
          ],
        ),
      );

      expect(find.textContaining('댓글'), findsOneWidget);
    });

    testWidgets('should reflect bookmarked state on the card', (tester) async {
      await pumpEntry(tester, isBookmarked: true);

      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });

    testWidgets('should call onBookmarkTap when bookmark icon tapped', (
      tester,
    ) async {
      var tapped = 0;
      await pumpEntry(tester, onBookmarkTap: () => tapped++);

      await tester.tap(find.byIcon(Icons.bookmark_border));
      expect(tapped, 1);
    });

    testWidgets('should copy post url and show snackbar when copy tapped', (
      tester,
    ) async {
      await pumpEntry(tester);

      await tester.tap(find.byIcon(Icons.link));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        clipboardContent,
        'https://m.humoruniv.com/board/read.html?table=pds&number=1',
      );
      expect(find.text('링크를 복사했어요'), findsOneWidget);
    });

    testWidgets('should pass detailLoading true while detail unresolved', (
      tester,
    ) async {
      await pumpEntry(tester, detailLoading: true);

      expect(find.byType(FeedCard), findsOneWidget);
    });
  });
}
