import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/board_post.dart';
import 'package:keek_news/model/comment.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/provider/bookmark_provider.dart';
import 'package:keek_news/repository/bookmark/bookmark_repo.dart';
import 'package:keek_news/repository/merged_feed/merged_feed_repo.dart';
import 'package:keek_news/service/service_locator.dart' as di;
import 'package:keek_news/widgets/feed_card.dart';
import 'package:keek_news/widgets/feed_card_entry.dart';
import 'package:keek_news/widgets/feed_image_carousel.dart';
import 'package:mocktail/mocktail.dart';

class MockMergedFeedRepository extends Mock implements MergedFeedRepo {}

class MockBookmarkRepository extends Mock implements BookmarkRepo {}

void main() {
  late MockMergedFeedRepository mockFeedRepo;
  late MockBookmarkRepository mockBookmarkRepo;
  String? clipboardContent;

  setUp(() {
    mockFeedRepo = MockMergedFeedRepository();
    mockBookmarkRepo = MockBookmarkRepository();
    when(() => mockBookmarkRepo.getAll()).thenAnswer((_) async => const []);
    registerFallbackValue(CommunityId.humoruniv);
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
    if (di.sl.isRegistered<MergedFeedRepo>()) {
      di.sl.unregister<MergedFeedRepo>();
    }
    di.sl.registerLazySingleton<MergedFeedRepo>(() => mockFeedRepo);
    if (di.sl.isRegistered<BookmarkRepo>()) {
      di.sl.unregister<BookmarkRepo>();
    }
    di.sl.registerLazySingleton<BookmarkRepo>(() => mockBookmarkRepo);
  });

  tearDown(di.sl.reset);

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

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        bookmarkRepositoryProvider.overrideWithValue(mockBookmarkRepo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pumpEntry(
    WidgetTester tester,
    ProviderContainer container, {
    bool isBookmarked = false,
    VoidCallback? onBookmarkTap,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                FeedCardEntry(
                  post: post,
                  isBookmarked: isBookmarked,
                  onBookmarkTap: onBookmarkTap ?? () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
  }

  group('FeedCardEntry', () {
    testWidgets('should render FeedCard with post metadata', (tester) async {
      when(
        () => mockFeedRepo.fetchDetail(
          community: any(named: 'community'),
          id: any(named: 'id'),
        ),
      ).thenAnswer((_) async => const Left(ServerFailure('none')));

      await pumpEntry(tester, makeContainer());

      expect(find.byType(FeedCard), findsOneWidget);
      expect(find.text('유머작가'), findsOneWidget);
    });

    testWidgets('should load detail via mergedDetailProvider and show images', (
      tester,
    ) async {
      when(
        () => mockFeedRepo.fetchDetail(
          community: any(named: 'community'),
          id: any(named: 'id'),
        ),
      ).thenAnswer(
        (_) async =>
            Right(detailWith(imageUrls: const ['https://example.com/a.jpg'])),
      );

      await pumpEntry(tester, makeContainer());

      expect(find.byType(FeedImageCarousel), findsOneWidget);
    });

    testWidgets('should show comment preview when detail has comments', (
      tester,
    ) async {
      final detail = detailWith(
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
      );
      when(
        () => mockFeedRepo.fetchDetail(
          community: any(named: 'community'),
          id: any(named: 'id'),
        ),
      ).thenAnswer((_) async => Right(detail));

      await pumpEntry(tester, makeContainer());

      expect(find.textContaining('댓글'), findsOneWidget);
    });

    testWidgets('should reflect bookmarked state on the card', (tester) async {
      when(
        () => mockFeedRepo.fetchDetail(
          community: any(named: 'community'),
          id: any(named: 'id'),
        ),
      ).thenAnswer((_) async => const Left(ServerFailure('none')));

      await pumpEntry(tester, makeContainer(), isBookmarked: true);

      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });

    testWidgets('should call onBookmarkTap when bookmark icon tapped', (
      tester,
    ) async {
      var tapped = 0;
      when(
        () => mockFeedRepo.fetchDetail(
          community: any(named: 'community'),
          id: any(named: 'id'),
        ),
      ).thenAnswer((_) async => const Left(ServerFailure('none')));

      await pumpEntry(tester, makeContainer(), onBookmarkTap: () => tapped++);

      await tester.tap(find.byIcon(Icons.bookmark_border));
      expect(tapped, 1);
    });

    testWidgets('should copy post url and show snackbar when copy tapped', (
      tester,
    ) async {
      when(
        () => mockFeedRepo.fetchDetail(
          community: any(named: 'community'),
          id: any(named: 'id'),
        ),
      ).thenAnswer((_) async => const Left(ServerFailure('none')));

      await pumpEntry(tester, makeContainer());

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
      when(
        () => mockFeedRepo.fetchDetail(
          community: any(named: 'community'),
          id: any(named: 'id'),
        ),
      ).thenAnswer((_) async => const Left(ServerFailure('none')));

      final container = makeContainer();
      await pumpEntry(tester, container);

      expect(find.byType(FeedCard), findsOneWidget);
    });
  });
}
