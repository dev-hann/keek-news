import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/feed_item_dto.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/repository/merged_feed/merged_feed_impl.dart';
import 'package:keek_news/service/community_adapter.dart';
import 'package:mocktail/mocktail.dart';

class MockCommunityAdapter extends Mock implements CommunityAdapter {}

void main() {
  late MockCommunityAdapter huAdapter;
  late MockCommunityAdapter thAdapter;
  late MergedFeedImpl repo;

  FeedItemDto dto(CommunityId c, String id, DateTime ts) => FeedItemDto(
    community: c,
    id: id,
    title: '$c-$id',
    url: 'url-$id',
    publishedAt: ts,
  );

  setUp(() {
    huAdapter = MockCommunityAdapter();
    thAdapter = MockCommunityAdapter();
    when(() => huAdapter.communityId).thenReturn(CommunityId.humoruniv);
    when(() => thAdapter.communityId).thenReturn(CommunityId.todayhumor);
    repo = MergedFeedImpl(
      adapters: {
        CommunityId.humoruniv: huAdapter,
        CommunityId.todayhumor: thAdapter,
      },
    );
  });

  group('MergedFeedImpl', () {
    test('should call fetchLatest on all adapters', () async {
      when(
        () => huAdapter.fetchLatest(pageToken: any(named: 'pageToken')),
      ).thenAnswer(
        (_) async => FeedListResult(
          items: [dto(CommunityId.humoruniv, '1', DateTime(2026, 7, 26, 10))],
        ),
      );
      when(
        () => thAdapter.fetchLatest(pageToken: any(named: 'pageToken')),
      ).thenAnswer(
        (_) async => FeedListResult(
          items: [dto(CommunityId.todayhumor, '1', DateTime(2026, 7, 26, 12))],
        ),
      );

      final result = await repo.fetchMerged(perSource: 10);

      verify(() => huAdapter.fetchLatest()).called(1);
      verify(() => thAdapter.fetchLatest()).called(1);
      expect(result.isRight(), isTrue);
    });

    test(
      'should return merged items sorted by publishedAt descending',
      () async {
        when(
          () => huAdapter.fetchLatest(pageToken: any(named: 'pageToken')),
        ).thenAnswer(
          (_) async => FeedListResult(
            items: [dto(CommunityId.humoruniv, '1', DateTime(2026, 7, 26, 10))],
          ),
        );
        when(
          () => thAdapter.fetchLatest(pageToken: any(named: 'pageToken')),
        ).thenAnswer(
          (_) async => FeedListResult(
            items: [
              dto(CommunityId.todayhumor, '1', DateTime(2026, 7, 26, 12)),
            ],
          ),
        );

        final result = await repo.fetchMerged(perSource: 10);

        final page = result.getOrElse(() => throw StateError('expected Right'));
        expect(page.items.first.community, CommunityId.todayhumor);
        expect(page.items.last.community, CommunityId.humoruniv);
      },
    );

    test(
      'should skip failed adapter and include it in failedSources',
      () async {
        when(
          () => huAdapter.fetchLatest(pageToken: any(named: 'pageToken')),
        ).thenAnswer(
          (_) async => FeedListResult(
            items: [dto(CommunityId.humoruniv, '1', DateTime(2026, 7, 26, 10))],
          ),
        );
        when(
          () => thAdapter.fetchLatest(pageToken: any(named: 'pageToken')),
        ).thenThrow(Exception('network error'));

        final result = await repo.fetchMerged(perSource: 10);

        final page = result.getOrElse(() => throw StateError('expected Right'));
        expect(page.items, hasLength(1));
        expect(page.failedSources, contains(CommunityId.todayhumor));
      },
    );

    test('should return Left when all adapters fail', () async {
      when(
        () => huAdapter.fetchLatest(pageToken: any(named: 'pageToken')),
      ).thenThrow(Exception('down'));
      when(
        () => thAdapter.fetchLatest(pageToken: any(named: 'pageToken')),
      ).thenThrow(Exception('down'));

      final result = await repo.fetchMerged(perSource: 10);

      expect(result.isLeft(), isTrue);
      expect(result.fold((f) => f, (_) => null), isA<ServerFailure>());
    });

    test('should pass cursor tokens to adapters', () async {
      when(
        () => huAdapter.fetchLatest(pageToken: any(named: 'pageToken')),
      ).thenAnswer(
        (_) async => FeedListResult(
          items: [dto(CommunityId.humoruniv, '1', DateTime(2026, 7, 26, 10))],
          pageToken: 'page3',
        ),
      );
      when(
        () => thAdapter.fetchLatest(pageToken: any(named: 'pageToken')),
      ).thenAnswer(
        (_) async => FeedListResult(
          items: [dto(CommunityId.todayhumor, '1', DateTime(2026, 7, 26, 12))],
          pageToken: 'page2',
        ),
      );

      final first = await repo.fetchMerged(perSource: 10);
      final page = first.getOrElse(() => throw StateError(''));
      final cursor = page.next!;

      expect(cursor.perSourceTokens[CommunityId.humoruniv], 'page3');
      expect(cursor.perSourceTokens[CommunityId.todayhumor], 'page2');
    });

    test('should filter to enabled communities only', () async {
      when(
        () => huAdapter.fetchLatest(pageToken: any(named: 'pageToken')),
      ).thenAnswer(
        (_) async => FeedListResult(
          items: [dto(CommunityId.humoruniv, '1', DateTime(2026, 7, 26, 10))],
        ),
      );

      await repo.fetchMerged(perSource: 10, enabled: {CommunityId.humoruniv});

      verify(() => huAdapter.fetchLatest()).called(1);
      verifyNever(
        () => thAdapter.fetchLatest(pageToken: any(named: 'pageToken')),
      );
    });
  });

  group('MergedFeedImpl detail cache', () {
    PostDetail detail() => PostDetail(
      id: 1,
      title: 't',
      author: 'a',
      date: DateTime(2026, 7, 30),
      contentHtml: '',
      contentBlocks: const [],
      imageUrls: const ['https://example.com/img.jpg'],
      recommendCount: 1,
      notRecommendCount: 0,
      viewCount: 1,
      commentCount: 0,
      comments: const [],
    );

    test('should cache detail — second call does not hit adapter', () async {
      when(
        () => huAdapter.fetchDetail('100'),
      ).thenAnswer((_) async => detail());

      await repo.fetchDetail(community: CommunityId.humoruniv, id: '100');
      await repo.fetchDetail(community: CommunityId.humoruniv, id: '100');

      verify(() => huAdapter.fetchDetail('100')).called(1);
    });

    test('should refetch after cacheTtl expires', () async {
      var now = DateTime(2026, 7, 30, 10);
      final timed = MergedFeedImpl(
        adapters: {CommunityId.humoruniv: huAdapter},
        detailCacheTtl: const Duration(minutes: 2),
        now: () => now,
      );
      when(
        () => huAdapter.fetchDetail('100'),
      ).thenAnswer((_) async => detail());

      await timed.fetchDetail(community: CommunityId.humoruniv, id: '100');
      now = now.add(const Duration(minutes: 3));
      await timed.fetchDetail(community: CommunityId.humoruniv, id: '100');

      verify(() => huAdapter.fetchDetail('100')).called(2);
    });

    test('should not cache failures', () async {
      when(() => huAdapter.fetchDetail('100')).thenThrow(Exception('down'));

      final first = await repo.fetchDetail(
        community: CommunityId.humoruniv,
        id: '100',
      );
      expect(first.isLeft(), isTrue);

      when(
        () => huAdapter.fetchDetail('100'),
      ).thenAnswer((_) async => detail());
      final second = await repo.fetchDetail(
        community: CommunityId.humoruniv,
        id: '100',
      );
      expect(second.isRight(), isTrue);

      verify(() => huAdapter.fetchDetail('100')).called(2);
    });

    test('should cache distinct keys independently', () async {
      when(
        () => huAdapter.fetchDetail('100'),
      ).thenAnswer((_) async => detail());
      when(
        () => huAdapter.fetchDetail('200'),
      ).thenAnswer((_) async => detail());

      await repo.fetchDetail(community: CommunityId.humoruniv, id: '100');
      await repo.fetchDetail(community: CommunityId.humoruniv, id: '200');
      await repo.fetchDetail(community: CommunityId.humoruniv, id: '100');
      await repo.fetchDetail(community: CommunityId.humoruniv, id: '200');

      verify(() => huAdapter.fetchDetail('100')).called(1);
      verify(() => huAdapter.fetchDetail('200')).called(1);
    });
  });
}
