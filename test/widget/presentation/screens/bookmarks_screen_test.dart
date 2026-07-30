import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/errors/failures.dart';
import 'package:happy_news/core/widgets/molecules/feed_card.dart';
import 'package:happy_news/core/widgets/states/empty_state_view.dart';
import 'package:happy_news/di/injection.dart' as di;
import 'package:happy_news/domain/entities/bookmark.dart';
import 'package:happy_news/domain/entities/community.dart';
import 'package:happy_news/domain/repositories/bookmark_repository.dart';
import 'package:happy_news/domain/repositories/merged_feed_repository.dart';
import 'package:happy_news/presentation/providers/bookmark_provider.dart';
import 'package:happy_news/presentation/screens/bookmarks_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockBookmarkRepository extends Mock implements BookmarkRepository {}

class MockMergedFeedRepository extends Mock implements MergedFeedRepository {}

Bookmark _bookmark({
  CommunityId community = CommunityId.humoruniv,
  String id = '1',
  String title = '저장된 글',
  String url = '/u',
}) {
  return Bookmark(
    community: community,
    id: id,
    title: title,
    url: url,
    author: '작성자',
    savedAt: DateTime(2026, 7, 30, 10),
  );
}

void main() {
  late MockBookmarkRepository repo;
  late MockMergedFeedRepository mockFeedRepo;
  String? clipboardContent;

  setUp(() {
    repo = MockBookmarkRepository();
    mockFeedRepo = MockMergedFeedRepository();
    registerFallbackValue(CommunityId.humoruniv);
    registerFallbackValue(
      Bookmark(
        community: CommunityId.humoruniv,
        id: 'fallback',
        title: '',
        url: '',
        savedAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    when(() => repo.getAll()).thenAnswer((_) async => const []);
    when(
      () => mockFeedRepo.fetchDetail(
        community: any(named: 'community'),
        id: any(named: 'id'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure('none')));
    if (di.sl.isRegistered<MergedFeedRepository>()) {
      di.sl.unregister<MergedFeedRepository>();
    }
    di.sl.registerLazySingleton<MergedFeedRepository>(() => mockFeedRepo);
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

  tearDown(di.sl.reset);

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [bookmarkRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    ProviderContainer container, {
    List<Bookmark> bookmarks = const [],
  }) async {
    when(() => repo.getAll()).thenAnswer((_) async => bookmarks);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: BookmarksScreen()),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
  }

  group('BookmarksScreen', () {
    testWidgets('should display AppBar with title 저장함', (tester) async {
      final container = makeContainer();
      await pumpScreen(tester, container);

      expect(find.text('저장함'), findsOneWidget);
    });

    testWidgets('should display EmptyStateView when no bookmarks', (
      tester,
    ) async {
      final container = makeContainer();
      await pumpScreen(tester, container, bookmarks: const []);

      expect(find.byType(EmptyStateView), findsOneWidget);
      expect(find.text('저장한 게시물이 없어요'), findsOneWidget);
      expect(find.text('좋아하는 글을 북마크해 보세요'), findsOneWidget);
    });

    testWidgets('should display bookmark icon in empty state', (tester) async {
      final container = makeContainer();
      await pumpScreen(tester, container, bookmarks: const []);

      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    });

    testWidgets('should render FeedCard for each bookmark', (tester) async {
      final container = makeContainer();
      await pumpScreen(
        tester,
        container,
        bookmarks: [
          _bookmark(id: '1', title: '첫 글'),
          _bookmark(id: '2', title: '둘 글'),
        ],
      );

      expect(find.byType(FeedCard), findsNWidgets(2));
      expect(find.text('첫 글'), findsOneWidget);
      expect(find.text('둘 글'), findsOneWidget);
    });

    testWidgets('should show filled bookmark icon on saved cards', (
      tester,
    ) async {
      final container = makeContainer();
      await pumpScreen(tester, container, bookmarks: [_bookmark(id: '1')]);

      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });

    testWidgets('should remove bookmark when bookmark icon tapped', (
      tester,
    ) async {
      final container = makeContainer();
      final bm = _bookmark(id: '1');
      when(
        () => repo.remove(CommunityId.humoruniv, '1'),
      ).thenAnswer((_) async {});
      await pumpScreen(tester, container, bookmarks: [bm]);

      await tester.tap(find.byIcon(Icons.bookmark));
      await tester.pumpAndSettle();

      verify(() => repo.remove(CommunityId.humoruniv, '1')).called(1);
    });

    testWidgets('should copy link to clipboard when copy icon tapped', (
      tester,
    ) async {
      final container = makeContainer();
      await pumpScreen(
        tester,
        container,
        bookmarks: [_bookmark(id: '1', url: '/copied-url')],
      );

      await tester.tap(find.byIcon(Icons.link));
      await tester.pump(const Duration(milliseconds: 300));

      expect(clipboardContent, 'https://m.humoruniv.com/copied-url');
    });

    testWidgets('should show snackbar after copying link', (tester) async {
      final container = makeContainer();
      await pumpScreen(
        tester,
        container,
        bookmarks: [_bookmark(id: '1', url: '/u')],
      );

      await tester.tap(find.byIcon(Icons.link));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('링크를 복사했어요'), findsOneWidget);
    });
  });
}
