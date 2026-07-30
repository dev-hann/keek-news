import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/themes/app_sizes.dart';
import 'package:happy_news/core/utils/time_ago.dart';
import 'package:happy_news/core/widgets/atoms/skeleton_box.dart';
import 'package:happy_news/core/widgets/molecules/feed_card.dart';
import 'package:happy_news/core/widgets/molecules/feed_image_carousel.dart';
import 'package:happy_news/domain/entities/board_post.dart';
import 'package:happy_news/domain/entities/comment.dart';
import 'package:happy_news/domain/entities/content_block.dart';
import 'package:happy_news/domain/entities/post_detail.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  group('FeedCard', () {
    const post = BoardPost(
      id: 1,
      title: '게시글 제목',
      url: '/board/read.html?table=pds&number=1',
      author: '유머작가',
      date: '2026-05-15',
      recommendCount: 42,
      notRecommendCount: 1,
      commentCount: 10,
      viewCount: 500,
      thumbnailUrl: '',
    );

    PostDetail detailWith({
      List<String> imageUrls = const [],
      List<ContentBlock> blocks = const [],
      List<Comment> comments = const [],
      int commentCount = 0,
    }) => PostDetail(
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
      commentCount: commentCount,
      comments: comments,
    );

    testWidgets('should display author and counts from list', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FeedCard(post: post)),
        ),
      );
      expect(find.text('유머작가'), findsOneWidget);
      expect(find.text('42'), findsWidgets);
      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('should show skeleton while detail loading', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FeedCard(post: post, detailLoading: true),
            ),
          ),
        ),
      );
      expect(find.byType(SkeletonBox), findsWidgets);
    });

    testWidgets('should show carousel when detail has images', (tester) async {
      final detail = detailWith(
        imageUrls: const [
          'https://example.com/a.jpg',
          'https://example.com/b.jpg',
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FeedCard(post: post, detail: detail),
            ),
          ),
        ),
      );
      expect(find.byType(FeedImageCarousel), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
    });

    testWidgets('should not show carousel for text post (no images)', (
      tester,
    ) async {
      final detail = detailWith(blocks: const [TextBlock('본문 내용')]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedCard(post: post, detail: detail),
          ),
        ),
      );
      expect(find.byType(FeedImageCarousel), findsNothing);
      expect(find.text('본문 내용'), findsOneWidget);
    });

    testWidgets(
      'renders a Material card surface for figure-ground separation',
      (tester) async {
        final detail = detailWith(imageUrls: ['https://example.com/a.jpg']);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FeedCard(post: post, detail: detail),
              ),
            ),
          ),
        );

        // The card is wrapped in a Material whose color is surfaceContainer, so
        // it contrasts with the scaffold behind it.
        final material = tester.widget<Material>(find.byType(Material).first);
        expect(material.color, isNotNull);
      },
    );

    testWidgets(
      'renders title + body in caption for a text-only post (no media block)',
      (tester) async {
        final detail = detailWith(blocks: const [TextBlock('본문 내용')]);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FeedCard(post: post, detail: detail),
              ),
            ),
          ),
        );

        // No media block for text-only posts; title and body both render in the
        // caption area (same layout as image posts, minus the carousel).
        expect(find.byType(FeedImageCarousel), findsNothing);
        expect(find.text('게시글 제목'), findsOneWidget);
        expect(find.text('본문 내용'), findsOneWidget);
      },
    );

    testWidgets('does not render a Divider between cards', (tester) async {
      final detail = detailWith(imageUrls: ['https://example.com/a.jpg']);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FeedCard(post: post, detail: detail),
            ),
          ),
        ),
      );

      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('should show title in caption', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FeedCard(post: post)),
        ),
      );
      expect(find.text('게시글 제목'), findsOneWidget);
    });

    testWidgets('should show BEST badge when recommendCount >= 500', (
      tester,
    ) async {
      const best = BoardPost(
        id: 3,
        title: 't',
        url: 'u',
        author: 'a',
        date: '2026-05-15',
        recommendCount: 500,
        notRecommendCount: 0,
        commentCount: 0,
        viewCount: 0,
        thumbnailUrl: '',
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FeedCard(post: best)),
        ),
      );
      expect(find.text('BEST'), findsOneWidget);
    });

    testWidgets('should show comment preview when detail has comments', (
      tester,
    ) async {
      final detail = detailWith(
        commentCount: 5,
        comments: [
          Comment(
            id: 1,
            author: '댓글러',
            content: '웃기다',
            date: DateTime(2026, 5, 15),
            recommendCount: 3,
            isBest: true,
            replies: const [],
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedCard(post: post, detail: detail),
          ),
        ),
      );
      expect(find.text('댓글 5개 모두 보기'), findsOneWidget);
    });

    testWidgets('should call onImageTap with index when image tapped', (
      tester,
    ) async {
      var tapped = -1;
      final detail = detailWith(imageUrls: const ['https://example.com/a.jpg']);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FeedCard(
                post: post,
                detail: detail,
                onImageTap: (i) => tapped = i,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(FeedImageCarousel));
      expect(tapped, 0);
    });

    testWidgets('should show formatted timestamp', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FeedCard(post: post)),
        ),
      );
      expect(find.text(TimeAgo.formatDateString('2026-05-15')), findsOneWidget);
    });

    testWidgets(
      'should render carousel with video when detail has VideoBlock',
      (tester) async {
        final detail = detailWith(
          blocks: const [VideoBlock(url: 'https://example.com/v.mp4')],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FeedCard(post: post, detail: detail),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(FeedImageCarousel), findsOneWidget);
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      },
    );

    testWidgets(
      '더보기 toggle touch target should be at least 44pt in both dims',
      (tester) async {
        final longBody = List.filled(80, '매우 긴 본문입니다.').join(' ');
        final detail = detailWith(blocks: [TextBlock(longBody)]);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FeedCard(post: post, detail: detail),
              ),
            ),
          ),
        );
        final toggleFinder = find.ancestor(
          of: find.text('더보기'),
          matching: find.byType(GestureDetector),
        );
        final size = tester.getSize(toggleFinder);
        expect(size.height, greaterThanOrEqualTo(AppSizes.minTouchTarget));
        expect(size.width, greaterThanOrEqualTo(AppSizes.minTouchTarget));
      },
    );

    testWidgets('comment preview touch target should be at least 44pt tall', (
      tester,
    ) async {
      final detail = detailWith(
        commentCount: 5,
        comments: [
          Comment(
            id: 1,
            author: '댓글러',
            content: '웃기다',
            date: DateTime(2026, 5, 15),
            recommendCount: 3,
            isBest: true,
            replies: const [],
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FeedCard(post: post, detail: detail),
            ),
          ),
        ),
      );
      final finder = find.ancestor(
        of: find.text('댓글 5개 모두 보기'),
        matching: find.byType(GestureDetector),
      );
      final size = tester.getSize(finder);
      expect(size.height, greaterThanOrEqualTo(AppSizes.minTouchTarget));
    });
  });

  group('FeedCard action buttons', () {
    const post = BoardPost(
      id: 1,
      title: '게시글 제목',
      url: '/board/read.html?table=pds&number=1',
      author: '유머작가',
      date: '2026-05-15',
      recommendCount: 42,
      notRecommendCount: 1,
      commentCount: 10,
      viewCount: 500,
      thumbnailUrl: '',
    );

    testWidgets('should render copy link button when onCopyTap provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedCard(post: post, onCopyTap: () {}),
          ),
        ),
      );

      expect(find.byIcon(Icons.link), findsOneWidget);
    });

    testWidgets('should call onCopyTap when copy button tapped', (
      tester,
    ) async {
      var tapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedCard(post: post, onCopyTap: () => tapped++),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.link));
      expect(tapped, 1);
    });

    testWidgets('should render bookmark button when onBookmarkTap provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedCard(post: post, onBookmarkTap: () {}),
          ),
        ),
      );

      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    });

    testWidgets('should call onBookmarkTap when bookmark button tapped', (
      tester,
    ) async {
      var tapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedCard(post: post, onBookmarkTap: () => tapped++),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.bookmark_border));
      expect(tapped, 1);
    });

    testWidgets('should show outline bookmark when not bookmarked', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedCard(
              post: post,
              isBookmarked: false,
              onBookmarkTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsNothing);
    });

    testWidgets('should show filled bookmark when bookmarked', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedCard(
              post: post,
              isBookmarked: true,
              onBookmarkTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border), findsNothing);
    });

    testWidgets('should render both action buttons when callbacks provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedCard(post: post, onCopyTap: () {}, onBookmarkTap: () {}),
          ),
        ),
      );

      expect(find.byIcon(Icons.link), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    });

    testWidgets('should not render action buttons when callbacks omitted', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FeedCard(post: post)),
        ),
      );

      expect(find.byIcon(Icons.link), findsNothing);
      expect(find.byIcon(Icons.bookmark_border), findsNothing);
    });
  });
}
