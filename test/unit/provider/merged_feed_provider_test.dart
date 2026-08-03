import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/merged_feed.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/provider/merged_feed_provider.dart';
import 'package:keek_news/service/service_locator.dart' as di;
import 'package:keek_news/use_case/feed_use_case.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/merged_feed_helper.dart';

void main() {
  late MockMergedFeedUseCase mockUseCase;

  setUpAll(() {
    registerMergedFeedFallbacks();
    registerFallbackValue(CommunityId.humoruniv);
  });

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockUseCase = MockMergedFeedUseCase();
    if (di.sl.isRegistered<FeedUseCase>()) {
      di.sl.unregister<FeedUseCase>();
    }
    di.sl.registerLazySingleton<FeedUseCase>(() => mockUseCase);
  });

  tearDown(di.sl.reset);

  FeedItem item({
    CommunityId community = CommunityId.humoruniv,
    String id = '1',
  }) {
    return FeedItem(
      community: community,
      id: id,
      title: 'title-$id',
      url: 'u-$id',
    );
  }

  group('MergedFeedNotifier.fetchNextPage', () {
    test(
      'should append new items and keep hasMore when cursor has token',
      () async {
        final firstPage = MergedPage(
          items: [
            item(),
            item(id: '2'),
          ],
          next: const MergedCursor(
            perSourceTokens: {CommunityId.humoruniv: '2'},
          ),
        );
        final secondPage = MergedPage(
          items: [item(id: '3')],
          next: const MergedCursor(
            perSourceTokens: {CommunityId.humoruniv: '3'},
          ),
        );

        var call = 0;
        when(
          () => mockUseCase.getMergedFeed(any()),
        ).thenAnswer((_) async => Right(call++ == 0 ? firstPage : secondPage));

        final notifier = MergedFeedNotifier();
        await notifier.fetch();
        await notifier.fetchNextPage();

        expect(notifier.state.items.map((e) => e.id), ['1', '2', '3']);
        expect(notifier.state.hasMore, isTrue);
        expect(notifier.state.isLoadingMore, isFalse);
      },
    );

    test('should set hasMore false when all source tokens are null', () async {
      final firstPage = MergedPage(
        items: [item()],
        next: const MergedCursor(perSourceTokens: {CommunityId.humoruniv: '2'}),
      );
      final exhaustedPage = MergedPage(
        items: [item(id: '2')],
        next: const MergedCursor(
          perSourceTokens: {CommunityId.humoruniv: null},
        ),
      );

      var call = 0;
      when(
        () => mockUseCase.getMergedFeed(any()),
      ).thenAnswer((_) async => Right(call++ == 0 ? firstPage : exhaustedPage));

      final notifier = MergedFeedNotifier();
      await notifier.fetch();
      await notifier.fetchNextPage();

      expect(notifier.state.items, hasLength(2));
      expect(notifier.state.hasMore, isFalse);
    });

    test('should dedup items already present by community:id', () async {
      final firstPage = MergedPage(
        items: [item()],
        next: const MergedCursor(perSourceTokens: {CommunityId.humoruniv: '2'}),
      );
      final overlapPage = MergedPage(
        items: [
          item(),
          item(id: '2'),
        ],
        next: const MergedCursor(perSourceTokens: {CommunityId.humoruniv: '3'}),
      );

      var call = 0;
      when(
        () => mockUseCase.getMergedFeed(any()),
      ).thenAnswer((_) async => Right(call++ == 0 ? firstPage : overlapPage));

      final notifier = MergedFeedNotifier();
      await notifier.fetch();
      await notifier.fetchNextPage();

      expect(notifier.state.items.map((e) => e.id), ['1', '2']);
    });

    test('should keep hasMore based on cursor on fetch failure', () async {
      final firstPage = MergedPage(
        items: [item()],
        next: const MergedCursor(perSourceTokens: {CommunityId.humoruniv: '2'}),
      );

      var call = 0;
      when(() => mockUseCase.getMergedFeed(any())).thenAnswer((_) async {
        call++;
        if (call == 1) return Right(firstPage);
        return const Left(ServerFailure('network down'));
      });

      final notifier = MergedFeedNotifier();
      await notifier.fetch();
      await notifier.fetchNextPage();

      expect(notifier.state.items.map((e) => e.id), ['1']);
      expect(notifier.state.isLoadingMore, isFalse);
      expect(notifier.state.hasMore, isTrue);
    });

    test(
      'should not fetch when hasMore is false even if cursor present',
      () async {
        final firstPage = MergedPage(
          items: [item()],
          next: const MergedCursor(
            perSourceTokens: {CommunityId.humoruniv: null},
          ),
        );

        when(
          () => mockUseCase.getMergedFeed(any()),
        ).thenAnswer((_) async => Right(firstPage));

        final notifier = MergedFeedNotifier();
        await notifier.fetch();

        verify(() => mockUseCase.getMergedFeed(any())).called(1);
        expect(notifier.state.hasMore, isFalse);

        await notifier.fetchNextPage();
        verifyNever(() => mockUseCase.getMergedFeed(any()));
      },
    );
  });

  group('MergedFeedNotifier.refresh', () {
    test('should replace items on success without showing skeleton', () async {
      final firstPage = MergedPage(items: [item()]);
      final refreshedPage = MergedPage(
        items: [
          item(id: '2'),
          item(id: '3'),
        ],
      );

      var call = 0;
      when(
        () => mockUseCase.getMergedFeed(any()),
      ).thenAnswer((_) async => Right(call++ == 0 ? firstPage : refreshedPage));

      final notifier = MergedFeedNotifier();
      await notifier.fetch();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.items.map((e) => e.id), ['1']);

      await notifier.refresh();

      expect(notifier.state.items.map((e) => e.id), ['2', '3']);
      expect(notifier.state.isLoading, isFalse);
    });

    test('should keep existing items when refresh fails', () async {
      final firstPage = MergedPage(items: [item()]);

      var call = 0;
      when(() => mockUseCase.getMergedFeed(any())).thenAnswer((_) async {
        call++;
        if (call == 1) return Right(firstPage);
        return const Left(ServerFailure('network down'));
      });

      final notifier = MergedFeedNotifier();
      await notifier.fetch();

      await notifier.refresh();

      expect(notifier.state.items.map((e) => e.id), ['1']);
      expect(notifier.state.error, isNull);
    });
  });

  group('MergedDetailNotifier.retryDetail', () {
    const key = (community: CommunityId.humoruniv, id: '1');

    test('clears cached error and re-fetches on retry', () async {
      var call = 0;
      when(
        () => mockUseCase.getPostDetail(
          community: any(named: 'community'),
          id: any(named: 'id'),
        ),
      ).thenAnswer((_) async {
        call++;
        if (call == 1) {
          return const ErrorPostDetail(
            id: 1,
            community: CommunityId.humoruniv,
            failure: NetworkFailure('flake'),
          );
        }
        return LoadedPostDetail(
          id: 1,
          title: 't',
          author: 'a',
          date: DateTime(2026),
          contentHtml: '',
          contentBlocks: const [],
          imageUrls: const [],
          recommendCount: 0,
          notRecommendCount: 0,
          viewCount: 0,
          commentCount: 0,
          comments: const [],
        );
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mergedDetailProvider.notifier);

      await notifier.fetchDetail(key);
      expect(
        container.read(mergedDetailProvider)[key]?.value,
        isA<ErrorPostDetail>(),
      );

      await notifier.retryDetail(key);

      expect(call, 2);
      expect(
        container.read(mergedDetailProvider)[key]?.value,
        isA<LoadedPostDetail>(),
      );
    });

    test('no-op when key not present', () async {
      when(
        () => mockUseCase.getPostDetail(
          community: any(named: 'community'),
          id: any(named: 'id'),
        ),
      ).thenAnswer(
        (_) async => const ErrorPostDetail(
          id: 1,
          community: CommunityId.humoruniv,
          failure: NetworkFailure('x'),
        ),
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mergedDetailProvider.notifier);

      // Key was never fetched → retryDetail does nothing.
      await notifier.retryDetail(key);

      verifyNever(
        () => mockUseCase.getPostDetail(
          community: any(named: 'community'),
          id: any(named: 'id'),
        ),
      );
    });
  });
}
