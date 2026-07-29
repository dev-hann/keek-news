import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/errors/failures.dart';
import 'package:happy_news/data/datasources/community_adapter.dart';
import 'package:happy_news/data/models/feed_item_dto.dart';
import 'package:happy_news/data/repositories/merged_feed_repository_impl.dart';
import 'package:happy_news/domain/entities/community.dart';
import 'package:mocktail/mocktail.dart';

class MockCommunityAdapter extends Mock implements CommunityAdapter {}

void main() {
  late MockCommunityAdapter huAdapter;
  late MockCommunityAdapter thAdapter;
  late MergedFeedRepositoryImpl repo;

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
    repo = MergedFeedRepositoryImpl(
      adapters: {
        CommunityId.humoruniv: huAdapter,
        CommunityId.todayhumor: thAdapter,
      },
    );
  });

  group('MergedFeedRepositoryImpl', () {
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

      verify(() => huAdapter.fetchLatest(pageToken: null)).called(1);
      verify(() => thAdapter.fetchLatest(pageToken: null)).called(1);
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

      verify(() => huAdapter.fetchLatest(pageToken: null)).called(1);
      verifyNever(
        () => thAdapter.fetchLatest(pageToken: any(named: 'pageToken')),
      );
    });
  });
}
