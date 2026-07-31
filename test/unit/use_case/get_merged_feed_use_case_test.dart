import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/merged_feed.dart';
import 'package:keek_news/repository/community_repo.dart';
import 'package:keek_news/use_case/get_merged_feed_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockCommunityRepo extends Mock implements CommunityRepo {}

void main() {
  late MockCommunityRepo humorunivRepo;
  late MockCommunityRepo dogdripRepo;
  late GetMergedFeedUseCase useCase;

  setUp(() {
    humorunivRepo = MockCommunityRepo();
    dogdripRepo = MockCommunityRepo();
    when(() => humorunivRepo.communityId).thenReturn(CommunityId.humoruniv);
    when(() => dogdripRepo.communityId).thenReturn(CommunityId.dogdrip);
    useCase = GetMergedFeedUseCase(
      repos: {
        CommunityId.humoruniv: humorunivRepo,
        CommunityId.dogdrip: dogdripRepo,
      },
    );
  });

  group('GetMergedFeedUseCase', () {
    test('should fan-out to all repos and merge results', () async {
      final item1 = FeedItem(
        community: CommunityId.humoruniv,
        id: '1',
        title: 'h',
        url: 'u1',
        publishedAt: DateTime(2026, 7, 28),
      );
      final item2 = FeedItem(
        community: CommunityId.dogdrip,
        id: '2',
        title: 'd',
        url: 'u2',
        publishedAt: DateTime(2026, 7, 29),
      );
      when(
        () => humorunivRepo.fetchLatest(pageToken: any(named: 'pageToken')),
      ).thenAnswer((_) async => CommunityListResult(items: [item1]));
      when(
        () => dogdripRepo.fetchLatest(pageToken: any(named: 'pageToken')),
      ).thenAnswer((_) async => CommunityListResult(items: [item2]));

      final result = await useCase(const MergedFeedParams());

      expect(result.isRight(), isTrue);
      final page = result.getOrElse(() => throw StateError(''));
      expect(page.items, hasLength(2));
      // dogdrip's item is newer → should come first after sort
      expect(page.items.first.id, '2');
    });

    test('should isolate failing repos and merge successful ones', () async {
      final item = FeedItem(
        community: CommunityId.dogdrip,
        id: '1',
        title: 'd',
        url: 'u',
        publishedAt: DateTime(2026, 7, 28),
      );
      when(
        () => humorunivRepo.fetchLatest(pageToken: any(named: 'pageToken')),
      ).thenThrow(Exception('humoruniv down'));
      when(
        () => dogdripRepo.fetchLatest(pageToken: any(named: 'pageToken')),
      ).thenAnswer((_) async => CommunityListResult(items: [item]));

      final result = await useCase(const MergedFeedParams());

      expect(result.isRight(), isTrue);
      final page = result.getOrElse(() => throw StateError(''));
      expect(page.failedSources, contains(CommunityId.humoruniv));
      expect(page.items, hasLength(1));
      expect(page.items.first.community, CommunityId.dogdrip);
    });

    test('should return Left when all repos fail', () async {
      when(
        () => humorunivRepo.fetchLatest(pageToken: any(named: 'pageToken')),
      ).thenThrow(Exception('down'));
      when(
        () => dogdripRepo.fetchLatest(pageToken: any(named: 'pageToken')),
      ).thenThrow(Exception('down'));

      final result = await useCase(const MergedFeedParams());

      expect(result.isLeft(), isTrue);
    });

    test('should respect enabled filter', () async {
      final item = FeedItem(
        community: CommunityId.humoruniv,
        id: '1',
        title: 'h',
        url: 'u',
        publishedAt: DateTime(2026, 7, 28),
      );
      when(
        () => humorunivRepo.fetchLatest(pageToken: any(named: 'pageToken')),
      ).thenAnswer((_) async => CommunityListResult(items: [item]));

      final result = await useCase(
        const MergedFeedParams(enabled: {CommunityId.humoruniv}),
      );

      verifyNever(
        () => dogdripRepo.fetchLatest(pageToken: any(named: 'pageToken')),
      );
      expect(result.isRight(), isTrue);
    });

    test(
      'should keep null-timestamp items on paginated call (no time filter)',
      () async {
        const nullTsItem = FeedItem(
          community: CommunityId.humoruniv,
          id: '10',
          title: 'no-ts',
          url: 'u10',
        );
        when(() => humorunivRepo.fetchLatest(pageToken: '2')).thenAnswer(
          (_) async =>
              const CommunityListResult(items: [nullTsItem], pageToken: '3'),
        );
        when(
          () => dogdripRepo.fetchLatest(pageToken: '2'),
        ).thenAnswer((_) async => const CommunityListResult(items: []));

        final result = await useCase(
          const MergedFeedParams(
            cursor: MergedCursor(
              perSourceTokens: {
                CommunityId.humoruniv: '2',
                CommunityId.dogdrip: '2',
              },
            ),
          ),
        );

        final page = result.getOrElse(() => throw StateError(''));
        expect(page.items, hasLength(1));
        expect(page.items.first.id, '10');
      },
    );

    test(
      'should pass per-source page token to each repo on pagination',
      () async {
        when(
          () => humorunivRepo.fetchLatest(pageToken: '2'),
        ).thenAnswer((_) async => const CommunityListResult(items: []));
        when(
          () => dogdripRepo.fetchLatest(pageToken: '5'),
        ).thenAnswer((_) async => const CommunityListResult(items: []));

        await useCase(
          const MergedFeedParams(
            cursor: MergedCursor(
              perSourceTokens: {
                CommunityId.humoruniv: '2',
                CommunityId.dogdrip: '5',
              },
            ),
          ),
        );

        verify(() => humorunivRepo.fetchLatest(pageToken: '2')).called(1);
        verify(() => dogdripRepo.fetchLatest(pageToken: '5')).called(1);
      },
    );

    test('should build next cursor from repo pageTokens', () async {
      when(
        () => humorunivRepo.fetchLatest(pageToken: any(named: 'pageToken')),
      ).thenAnswer(
        (_) async => const CommunityListResult(
          items: [
            FeedItem(
              community: CommunityId.humoruniv,
              id: '1',
              title: 'h',
              url: 'u',
            ),
          ],
          pageToken: '2',
        ),
      );
      when(
        () => dogdripRepo.fetchLatest(pageToken: any(named: 'pageToken')),
      ).thenAnswer(
        (_) async => const CommunityListResult(
          items: [
            FeedItem(
              community: CommunityId.dogdrip,
              id: '2',
              title: 'd',
              url: 'u2',
            ),
          ],
        ),
      );

      final result = await useCase(const MergedFeedParams());
      final page = result.getOrElse(() => throw StateError(''));

      expect(page.next, isNotNull);
      expect(page.next!.perSourceTokens[CommunityId.humoruniv], '2');
      expect(page.next!.perSourceTokens[CommunityId.dogdrip], isNull);
      expect(page.next!.hasMore, isTrue);
    });
  });
}
