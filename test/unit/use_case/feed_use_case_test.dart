import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/comment.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/merged_feed.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/repository/community/community_repo.dart';
import 'package:keek_news/use_case/feed_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockCommunityRepo extends Mock implements CommunityRepo {}

void main() {
  late MockCommunityRepo humorunivRepo;
  late MockCommunityRepo dogdripRepo;
  late FeedUseCase useCase;

  setUp(() {
    humorunivRepo = MockCommunityRepo();
    dogdripRepo = MockCommunityRepo();
    when(() => humorunivRepo.communityId).thenReturn(CommunityId.humoruniv);
    when(() => dogdripRepo.communityId).thenReturn(CommunityId.dogdrip);
    useCase = FeedUseCase(
      repos: {
        CommunityId.humoruniv: humorunivRepo,
        CommunityId.dogdrip: dogdripRepo,
      },
    );
  });

  group('FeedUseCase', () {
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

      final result = await useCase.getMergedFeed(const MergedFeedParams());

      expect(result.isRight(), isTrue);
      final page = result.getOrElse(() => throw StateError(''));
      expect(page.items, hasLength(2));
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
      ).thenAnswer((_) async => throw const ServerFailure('humoruniv down'));
      when(
        () => dogdripRepo.fetchLatest(pageToken: any(named: 'pageToken')),
      ).thenAnswer((_) async => CommunityListResult(items: [item]));

      final result = await useCase.getMergedFeed(const MergedFeedParams());

      expect(result.isRight(), isTrue);
      final page = result.getOrElse(() => throw StateError(''));
      expect(page.failedSources, contains(CommunityId.humoruniv));
      expect(page.items, hasLength(1));
      expect(page.items.first.community, CommunityId.dogdrip);
    });

    test('should return Left when all repos fail', () async {
      when(
        () => humorunivRepo.fetchLatest(pageToken: any(named: 'pageToken')),
      ).thenAnswer((_) async => throw const ServerFailure('down'));
      when(
        () => dogdripRepo.fetchLatest(pageToken: any(named: 'pageToken')),
      ).thenAnswer((_) async => throw const ServerFailure('down'));

      final result = await useCase.getMergedFeed(const MergedFeedParams());

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

      final result = await useCase.getMergedFeed(
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

        final result = await useCase.getMergedFeed(
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

        await useCase.getMergedFeed(
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

      final result = await useCase.getMergedFeed(const MergedFeedParams());
      final page = result.getOrElse(() => throw StateError(''));

      expect(page.next, isNotNull);
      expect(page.next!.perSourceTokens[CommunityId.humoruniv], '2');
      expect(page.next!.perSourceTokens[CommunityId.dogdrip], isNull);
      expect(page.next!.hasMore, isTrue);
    });
  });

  group('FeedUseCase.getPostDetail', () {
    LoadedPostDetail loaded({
      List<ContentBlock> blocks = const [],
      List<String> imageUrls = const [],
      List<Comment> comments = const [],
    }) => LoadedPostDetail(
      id: 1,
      title: 't',
      author: 'a',
      date: DateTime(2026),
      contentHtml: '',
      contentBlocks: blocks,
      imageUrls: imageUrls,
      recommendCount: 0,
      notRecommendCount: 0,
      viewCount: 0,
      commentCount: comments.length,
      comments: comments,
    );

    test('returns LoadedPostDetail on successful non-empty detail', () async {
      when(() => humorunivRepo.fetchDetail('1')).thenAnswer(
        (_) async => loaded(imageUrls: const ['https://e.com/x.jpg']),
      );

      final result = await useCase.getPostDetail(
        community: CommunityId.humoruniv,
        id: '1',
      );

      expect(result, isA<LoadedPostDetail>());
    });

    test('returns ErrorPostDetail when repo throws', () async {
      when(() => humorunivRepo.fetchDetail('1')).thenAnswer(
        (_) async => throw const NetworkFailure('connection timed out'),
      );

      final result = await useCase.getPostDetail(
        community: CommunityId.humoruniv,
        id: '1',
      );

      expect(result, isA<ErrorPostDetail>());
      final err = result as ErrorPostDetail;
      expect(err.community, CommunityId.humoruniv);
      expect(err.failure, isA<NetworkFailure>());
      expect(err.id, 1);
    });

    test(
      'returns ErrorPostDetail(ParseFailure) when detail looks empty (block)',
      () async {
        when(() => humorunivRepo.fetchDetail('1')).thenAnswer(
          (_) async => loaded(), // empty content/images/comments
        );

        final result = await useCase.getPostDetail(
          community: CommunityId.humoruniv,
          id: '1',
        );

        expect(result, isA<ErrorPostDetail>());
        expect((result as ErrorPostDetail).failure, isA<ParseFailure>());
      },
    );

    test('returns ErrorPostDetail when community has no repo', () async {
      final result = await useCase.getPostDetail(
        community: CommunityId.ppomppu,
        id: '1',
      );

      expect(result, isA<ErrorPostDetail>());
      expect((result as ErrorPostDetail).failure, isA<ServerFailure>());
    });

    test('non-empty post with comments is not treated as block', () async {
      when(() => humorunivRepo.fetchDetail('1')).thenAnswer(
        (_) async => loaded(
          comments: [
            Comment(
              id: 1,
              author: 'a',
              content: 'c',
              date: DateTime(2026),
              recommendCount: 0,
              isBest: false,
              replies: const [],
            ),
          ],
        ),
      );

      final result = await useCase.getPostDetail(
        community: CommunityId.humoruniv,
        id: '1',
      );

      expect(result, isA<LoadedPostDetail>());
    });
  });
}
