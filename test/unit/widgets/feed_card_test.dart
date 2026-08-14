import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/comment.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/theme/shad_theme.dart';
import 'package:keek_news/utils/time_ago.dart';
import 'package:keek_news/widgets/feed_card.dart';
import 'package:keek_news/widgets/feed_image_carousel.dart';
import 'package:keek_news/widgets/skeleton_box.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../helpers/shad_harness.dart';

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  group('FeedCard', () {
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

    LoadedPostDetail detailWith({
      List<String> imageUrls = const [],
      List<ContentBlock> blocks = const [],
      List<Comment> comments = const [],
      int commentCount = 0,
    }) => LoadedPostDetail(
      id: 1,
      community: CommunityId.humoruniv,
      title: '게시글 제목',
      author: '유머작가',
      date: DateTime(2026, 5, 15),
      contentBlocks: blocks,
      imageUrls: imageUrls,
      recommendCount: 42,
      notRecommendCount: 1,
      viewCount: 500,
      commentCount: commentCount,
      comments: comments,
    );

    testWidgets('should display author and counts from list', (tester) async {
      await tester.pumpWidget(shadHarness(const FeedCard(post: post)));
      expect(find.text('유머작가'), findsOneWidget);
      expect(find.text('42'), findsWidgets);
      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('should show skeleton while detail loading', (tester) async {
      await tester.pumpWidget(
        shadHarness(
          const SingleChildScrollView(
            child: FeedCard(post: post, detailLoading: true),
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
        shadHarness(
          SingleChildScrollView(
            child: FeedCard(post: post, detail: detail),
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
        shadHarness(FeedCard(post: post, detail: detail)),
      );
      expect(find.byType(FeedImageCarousel), findsNothing);
      expect(find.text('본문 내용'), findsOneWidget);
    });

    testWidgets(
      'renders a Material card surface for figure-ground separation',
      (tester) async {
        final detail = detailWith(imageUrls: ['https://example.com/a.jpg']);
        await tester.pumpWidget(
          shadHarness(
            SingleChildScrollView(
              child: FeedCard(post: post, detail: detail),
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
          shadHarness(
            SingleChildScrollView(
              child: FeedCard(post: post, detail: detail),
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
        shadHarness(
          SingleChildScrollView(
            child: FeedCard(post: post, detail: detail),
          ),
        ),
      );

      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('should show title in caption', (tester) async {
      await tester.pumpWidget(shadHarness(const FeedCard(post: post)));
      expect(find.text('게시글 제목'), findsOneWidget);
    });

    testWidgets('should show BEST badge when recommendCount >= 500', (
      tester,
    ) async {
      const best = FeedItem(
        community: CommunityId.humoruniv,
        id: '3',
        title: 't',
        url: 'u',
        author: 'a',
        recommendCount: 500,
      );
      await tester.pumpWidget(shadHarness(const FeedCard(post: best)));
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
        shadHarness(FeedCard(post: post, detail: detail)),
      );
      expect(find.text('댓글 5개 모두 보기'), findsOneWidget);
    });

    testWidgets('should call onImageTap with index when image tapped', (
      tester,
    ) async {
      var tapped = -1;
      final detail = detailWith(imageUrls: const ['https://example.com/a.jpg']);
      await tester.pumpWidget(
        shadHarness(
          SingleChildScrollView(
            child: FeedCard(
              post: post,
              detail: detail,
              onImageTap: (i) => tapped = i,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(FeedImageCarousel));
      expect(tapped, 0);
    });

    testWidgets('should show formatted timestamp', (tester) async {
      final post = FeedItem(
        community: CommunityId.humoruniv,
        id: '1',
        title: '게시글 제목',
        url: '/u',
        publishedAt: DateTime(2026, 5, 15),
      );
      await tester.pumpWidget(shadHarness(FeedCard(post: post)));
      expect(find.text(TimeAgo.format(DateTime(2026, 5, 15))), findsOneWidget);
    });

    testWidgets(
      'should render carousel with video when detail has VideoBlock',
      (tester) async {
        final detail = detailWith(
          blocks: const [VideoBlock(url: 'https://example.com/v.mp4')],
        );
        await tester.pumpWidget(
          shadHarness(
            SingleChildScrollView(
              child: FeedCard(post: post, detail: detail),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(FeedImageCarousel), findsOneWidget);
        expect(find.byIcon(LucideIcons.play), findsOneWidget);
      },
    );

    testWidgets(
      '더보기 toggle touch target should be at least 44pt in both dims',
      (tester) async {
        final longBody = List.filled(80, '매우 긴 본문입니다.').join(' ');
        final detail = detailWith(blocks: [TextBlock(longBody)]);
        await tester.pumpWidget(
          shadHarness(
            SingleChildScrollView(
              child: FeedCard(post: post, detail: detail),
            ),
          ),
        );
        final toggleFinder = find.ancestor(
          of: find.text('더보기'),
          matching: find.byType(GestureDetector),
        );
        final size = tester.getSize(toggleFinder);
        expect(size.height, greaterThanOrEqualTo(44));
        expect(size.width, greaterThanOrEqualTo(44));
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
        shadHarness(
          SingleChildScrollView(
            child: FeedCard(post: post, detail: detail),
          ),
        ),
      );
      final finder = find.ancestor(
        of: find.text('댓글 5개 모두 보기'),
        matching: find.byType(GestureDetector),
      );
      final size = tester.getSize(finder);
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('더보기 tap expands body and reveals 접기', (tester) async {
      final body = List.generate(15, (i) => '본문 ${i + 1}번 줄').join('\n');
      final detail = detailWith(blocks: [TextBlock(body)]);
      await tester.pumpWidget(
        shadHarness(
          SingleChildScrollView(
            child: FeedCard(post: post, detail: detail),
          ),
        ),
      );
      final collapsedHeight = tester.getSize(find.text(body)).height;
      expect(find.text('더보기'), findsOneWidget);

      await tester.tap(find.text('더보기'));
      await tester.pumpAndSettle();

      expect(find.text('접기'), findsOneWidget);
      expect(find.text('더보기'), findsNothing);
      final expandedHeight = tester.getSize(find.text(body)).height;
      expect(expandedHeight, greaterThan(collapsedHeight));
    });

    testWidgets('long single-line body (no newlines) expands to full height', (
      tester,
    ) async {
      final body = '매우긴본문입니다' * 200;
      final detail = detailWith(blocks: [TextBlock(body)]);
      await tester.pumpWidget(
        shadHarness(
          SingleChildScrollView(
            child: FeedCard(post: post, detail: detail),
          ),
        ),
      );
      expect(find.text('더보기'), findsOneWidget);
      final collapsedHeight = tester.getSize(find.text(body)).height;

      await tester.tap(find.text('더보기'));
      await tester.pumpAndSettle();

      expect(find.text('접기'), findsOneWidget);
      expect(find.text('더보기'), findsNothing);
      final expandedHeight = tester.getSize(find.text(body)).height;
      expect(expandedHeight, greaterThan(collapsedHeight));
    });

    testWidgets('접기 tap collapses body back to 더보기', (tester) async {
      final body = List.generate(15, (i) => '본문 ${i + 1}번 줄').join('\n');
      final detail = detailWith(blocks: [TextBlock(body)]);
      await tester.pumpWidget(
        shadHarness(
          SingleChildScrollView(
            child: FeedCard(post: post, detail: detail),
          ),
        ),
      );
      final collapsedHeight = tester.getSize(find.text(body)).height;
      await tester.tap(find.text('더보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('접기'));
      await tester.pumpAndSettle();

      expect(find.text('더보기'), findsOneWidget);
      expect(find.text('접기'), findsNothing);
      expect(tester.getSize(find.text(body)).height, equals(collapsedHeight));
    });

    testWidgets('short body does not show 더보기', (tester) async {
      final detail = detailWith(blocks: const [TextBlock('짧은 본문입니다.')]);
      await tester.pumpWidget(
        shadHarness(
          SingleChildScrollView(
            child: FeedCard(post: post, detail: detail),
          ),
        ),
      );
      expect(find.text('더보기'), findsNothing);
    });

    testWidgets(
      '더보기 appears under enlarged text scale (textScaler respected)',
      (tester) async {
        final body = List.filled(30, '一二三四五六七八九十').join(' ');
        final detail = detailWith(blocks: [TextBlock(body)]);
        await tester.pumpWidget(
          ShadApp(
            title: 'test',
            themeMode: ThemeMode.dark,
            darkTheme: AppShadTheme.dark(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: FeedCard(post: post, detail: detail),
                ),
              ),
            ),
          ),
        );
        expect(find.text('더보기'), findsOneWidget);
      },
    );
  });

  group('FeedCard action buttons', () {
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

    testWidgets('should render copy link button when onCopyTap provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        shadHarness(FeedCard(post: post, onCopyTap: () {})),
      );

      expect(find.byIcon(LucideIcons.link), findsOneWidget);
    });

    testWidgets('should call onCopyTap when copy button tapped', (
      tester,
    ) async {
      var tapped = 0;
      await tester.pumpWidget(
        shadHarness(FeedCard(post: post, onCopyTap: () => tapped++)),
      );

      await tester.tap(find.byIcon(LucideIcons.link));
      expect(tapped, 1);
    });

    testWidgets('should render bookmark button when onBookmarkTap provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        shadHarness(FeedCard(post: post, onBookmarkTap: () {})),
      );

      expect(find.byIcon(LucideIcons.bookmark), findsOneWidget);
    });

    testWidgets('should call onBookmarkTap when bookmark button tapped', (
      tester,
    ) async {
      var tapped = 0;
      await tester.pumpWidget(
        shadHarness(FeedCard(post: post, onBookmarkTap: () => tapped++)),
      );

      await tester.tap(find.byIcon(LucideIcons.bookmark));
      expect(tapped, 1);
    });

    testWidgets('should show outline bookmark when not bookmarked', (
      tester,
    ) async {
      await tester.pumpWidget(
        shadHarness(FeedCard(post: post, onBookmarkTap: () {})),
      );

      expect(find.byIcon(LucideIcons.bookmark), findsOneWidget);
      expect(find.byIcon(LucideIcons.bookmarkCheck), findsNothing);
    });

    testWidgets('should show filled bookmark when bookmarked', (tester) async {
      await tester.pumpWidget(
        shadHarness(
          FeedCard(post: post, isBookmarked: true, onBookmarkTap: () {}),
        ),
      );

      expect(find.byIcon(LucideIcons.bookmarkCheck), findsOneWidget);
      expect(find.byIcon(LucideIcons.bookmark), findsNothing);
    });

    testWidgets('should render both action buttons when callbacks provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        shadHarness(
          FeedCard(post: post, onCopyTap: () {}, onBookmarkTap: () {}),
        ),
      );

      expect(find.byIcon(LucideIcons.link), findsOneWidget);
      expect(find.byIcon(LucideIcons.bookmark), findsOneWidget);
    });

    testWidgets('should not render action buttons when callbacks omitted', (
      tester,
    ) async {
      await tester.pumpWidget(shadHarness(const FeedCard(post: post)));

      expect(find.byIcon(LucideIcons.link), findsNothing);
      expect(find.byIcon(LucideIcons.bookmark), findsNothing);
    });
  });
}
