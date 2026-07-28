import 'package:flutter_test/flutter_test.dart';
import 'package:humoruniv/data/datasources/humoruniv_adapter_impl.dart';
import 'package:humoruniv/data/datasources/humoruniv_remote_ds.dart';
import 'package:humoruniv/data/models/board_post_dto.dart';
import 'package:humoruniv/domain/entities/community.dart';
import 'package:humoruniv/domain/entities/post_detail.dart';
import 'package:mocktail/mocktail.dart';

class MockHumorunivRemoteDs extends Mock implements HumorunivRemoteDs {}

void main() {
  late MockHumorunivRemoteDs mockDs;
  late HumorunivAdapterImpl adapter;

  setUp(() {
    mockDs = MockHumorunivRemoteDs();
    adapter = HumorunivAdapterImpl(remoteDs: mockDs);
  });

  group('HumorunivAdapterImpl', () {
    test('communityId should be humoruniv', () {
      expect(adapter.communityId, CommunityId.humoruniv);
    });

    test('fetchLatest should convert BoardPostDto to FeedItemDto', () async {
      when(() => mockDs.fetchBoardList('pds', 1, '')).thenAnswer(
        (_) async => BoardListDsResult(
          posts: [
            BoardPostDto(
              id: 100,
              title: '첫 글',
              url: '/board/read.html?table=pds&number=100',
              author: '작성자',
              date: '26/07/28',
              recommendCount: 42,
              notRecommendCount: 0,
              commentCount: 5,
              viewCount: 1000,
              thumbnailUrl: '',
            ),
          ],
          currentPage: 1,
          totalPage: 10,
        ),
      );

      final result = await adapter.fetchLatest();

      expect(result.items, hasLength(1));
      expect(result.items[0].community, CommunityId.humoruniv);
      expect(result.items[0].id, '100');
      expect(result.items[0].title, '첫 글');
      expect(result.items[0].recommendCount, 42);
      expect(result.pageToken, '2');
    });

    test('fetchLatest should return empty list when board is empty', () async {
      when(() => mockDs.fetchBoardList(any(), any(), any())).thenAnswer(
        (_) async =>
            const BoardListDsResult(posts: [], currentPage: 1, totalPage: 0),
      );

      final result = await adapter.fetchLatest();

      expect(result.items, isEmpty);
    });

    test('fetchLatest should return null pageToken on last page', () async {
      when(() => mockDs.fetchBoardList('pds', 5, '')).thenAnswer(
        (_) async =>
            const BoardListDsResult(posts: [], currentPage: 5, totalPage: 5),
      );

      final result = await adapter.fetchLatest(pageToken: '5');

      expect(result.pageToken, isNull);
    });

    test('fetchDetail should construct correct URL from id', () async {
      const id = '1419304';
      const expectedUrl = '/board/read.html?table=pds&number=1419304';
      when(() => mockDs.fetchPostDetail(expectedUrl)).thenAnswer(
        (_) async => PostDetail(
          id: 1419304,
          title: 'test',
          author: 'a',
          date: DateTime(2026, 7, 28),
          contentHtml: '',
          contentBlocks: const [],
          imageUrls: const [],
          recommendCount: 0,
          notRecommendCount: 0,
          viewCount: 0,
          commentCount: 0,
          comments: const [],
        ),
      );

      await adapter.fetchDetail(id);

      verify(() => mockDs.fetchPostDetail(expectedUrl)).called(1);
    });

    test(
      'healthCheck should return true when fetchBoardList succeeds',
      () async {
        when(() => mockDs.fetchBoardList(any(), any(), any())).thenAnswer(
          (_) async =>
              const BoardListDsResult(posts: [], currentPage: 1, totalPage: 0),
        );

        final healthy = await adapter.healthCheck();

        expect(healthy, isTrue);
      },
    );

    test(
      'healthCheck should return false when fetchBoardList throws',
      () async {
        when(
          () => mockDs.fetchBoardList(any(), any(), any()),
        ).thenThrow(Exception('down'));

        final healthy = await adapter.healthCheck();

        expect(healthy, isFalse);
      },
    );
  });
}
