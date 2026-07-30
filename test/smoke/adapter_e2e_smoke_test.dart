import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/board_post_dto.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/service/dogdrip_adapter_impl.dart';
import 'package:keek_news/service/html_client.dart';
import 'package:keek_news/service/humoruniv_adapter_impl.dart';
import 'package:keek_news/service/humoruniv_remote_ds.dart';
import 'package:keek_news/service/ppomppu_adapter_impl.dart';
import 'package:keek_news/service/todayhumor_adapter_impl.dart';
import 'package:mocktail/mocktail.dart';

class _MockHumorunivDs extends Mock implements HumorunivRemoteDs {}

class _RecordingHtmlClient implements HtmlClient {
  _RecordingHtmlClient(this._fixtures);
  final Map<String, String> _fixtures;
  final List<String> requestedUrls = [];

  @override
  Future<String> get(String path) async {
    requestedUrls.add(path);
    for (final entry in _fixtures.entries) {
      if (path.contains(entry.key)) return entry.value;
    }
    throw Exception('No fixture for: $path');
  }
}

String _fixture(String path) => File('test/fixtures/$path').readAsStringSync();

void main() {
  group('어댑터 파이프라인: URL 생성 + 데이터 파싱 검증', () {
    test('humoruniv: fetchLatest가 pds 보드를 요청하고 FeedItemDto 생성', () async {
      final ds = _MockHumorunivDs();
      when(() => ds.fetchBoardList('pds', 1, '')).thenAnswer(
        (_) async => const BoardListDsResult(
          posts: [
            BoardPostDto(
              id: 100,
              title: '테스트 글',
              url: '/board/read.html?table=pds&number=100',
              author: '작성자',
              date: '26/07/28',
              recommendCount: 50,
              notRecommendCount: 0,
              commentCount: 3,
              viewCount: 500,
              thumbnailUrl: '',
            ),
          ],
          currentPage: 1,
          totalPage: 10,
        ),
      );

      final adapter = HumorunivAdapterImpl(remoteDs: ds);
      final result = await adapter.fetchLatest();

      verify(() => ds.fetchBoardList('pds', 1, '')).called(1);
      expect(result.items, hasLength(1));
      expect(result.items.first.id, '100');
      expect(result.items.first.title, '테스트 글');
      expect(result.items.first.author, '작성자');
      expect(result.pageToken, '2');
    });

    test('humoruniv: fetchDetail(id)가 올바른 URL 생성', () async {
      final ds = _MockHumorunivDs();
      const expectedUrl = '/board/read.html?table=pds&number=100';
      when(() => ds.fetchPostDetail(expectedUrl)).thenAnswer(
        (_) async => PostDetail(
          id: 100,
          title: '상세',
          author: 'a',
          date: DateTime(2026, 7, 28),
          contentHtml: '<p>내용</p>',
          contentBlocks: const [],
          imageUrls: const ['https://img.jpg'],
          recommendCount: 10,
          notRecommendCount: 0,
          viewCount: 200,
          commentCount: 5,
          comments: const [],
        ),
      );

      final adapter = HumorunivAdapterImpl(remoteDs: ds);
      await adapter.fetchDetail('100');

      verify(() => ds.fetchPostDetail(expectedUrl)).called(1);
    });

    test('todayhumor: fetchLatest가 list.php 요청하고 타임스탬프 포함', () async {
      final client = _RecordingHtmlClient({
        'list.php?table=humorbest': _fixture(
          'todayhumor/list_humorbest_pc.html',
        ),
      });
      final adapter = TodayhumorAdapterImpl(htmlClient: client);

      final result = await adapter.fetchLatest();

      expect(
        client.requestedUrls.any((u) => u.contains('list.php')),
        isTrue,
        reason: 'list.php URL을 요청해야 함',
      );
      expect(result.items, isNotEmpty);
      expect(result.items.first.community, CommunityId.todayhumor);
      expect(
        result.items.first.publishedAt,
        isNotNull,
        reason: '오유는 타임스탬프가 파싱되어야 함',
      );
    });

    test('todayhumor: fetchDetail(id)가 view.php?no=id URL 생성', () async {
      final client = _RecordingHtmlClient({
        'view.php': _fixture('todayhumor/detail_483503.html'),
      });
      final adapter = TodayhumorAdapterImpl(htmlClient: client);

      await adapter.fetchDetail('483503');

      expect(
        client.requestedUrls.any(
          (u) => u.contains('view.php') && u.contains('no=483503'),
        ),
        isTrue,
        reason: 'view.php?no=483503 URL을 생성해야 함',
      );
    });

    test('ppomppu: fetchLatest가 zboard.php 요청', () async {
      final client = _RecordingHtmlClient({
        'zboard.php?id=humor': _fixture('ppomppu/list_humor.html'),
      });
      final adapter = PpomppuAdapterImpl(htmlClient: client);

      final result = await adapter.fetchLatest();

      expect(client.requestedUrls.any((u) => u.contains('zboard.php')), isTrue);
      expect(result.items, isNotEmpty);
      expect(result.items.first.community, CommunityId.ppomppu);
    });

    test('ppomppu: fetchDetail(id)가 view.php?no=id URL 생성', () async {
      final client = _RecordingHtmlClient({
        'view.php': _fixture('ppomppu/detail_770409.html'),
      });
      final adapter = PpomppuAdapterImpl(htmlClient: client);

      await adapter.fetchDetail('770409');

      expect(
        client.requestedUrls.any(
          (u) => u.contains('view.php') && u.contains('no=770409'),
        ),
        isTrue,
        reason: 'view.php?id=humor&no=770409 URL을 생성해야 함',
      );
    });

    test('dogdrip: fetchLatest가 mid=dogdrip 요청', () async {
      final client = _RecordingHtmlClient({
        'mid=dogdrip': _fixture('dogdrip/list_dogdrip.html'),
      });
      final adapter = DogdripAdapterImpl(htmlClient: client);

      final result = await adapter.fetchLatest();

      expect(
        client.requestedUrls.any((u) => u.contains('mid=dogdrip')),
        isTrue,
      );
      expect(result.items, isNotEmpty);
      expect(result.items.first.community, CommunityId.dogdrip);
    });

    test('dogdrip: fetchDetail(id)가 /id URL 생성', () async {
      final client = _RecordingHtmlClient({
        '716024142': _fixture('dogdrip/detail_716024142.html'),
      });
      final adapter = DogdripAdapterImpl(htmlClient: client);

      await adapter.fetchDetail('716024142');

      expect(
        client.requestedUrls.any((u) => u == '/716024142'),
        isTrue,
        reason: '/716024142 URL을 생성해야 함',
      );
    });

    test('humoruniv: 페이지네이션 — pageToken 2 전달 시 pg=2 요청', () async {
      final ds = _MockHumorunivDs();
      when(() => ds.fetchBoardList('pds', 2, '')).thenAnswer(
        (_) async =>
            const BoardListDsResult(posts: [], currentPage: 2, totalPage: 10),
      );

      final adapter = HumorunivAdapterImpl(remoteDs: ds);
      await adapter.fetchLatest(pageToken: '2');

      verify(() => ds.fetchBoardList('pds', 2, '')).called(1);
    });

    test('전체 파이프라인: 리스트 → 상세까지 id 일관성 유지', () async {
      final ds = _MockHumorunivDs();
      when(() => ds.fetchBoardList('pds', 1, '')).thenAnswer(
        (_) async => const BoardListDsResult(
          posts: [
            BoardPostDto(
              id: 42,
              title: '일관성 테스트',
              url: '/board/read.html?table=pds&number=42',
              author: 'tester',
              date: '26/07/28',
              recommendCount: 1,
              notRecommendCount: 0,
              commentCount: 0,
              viewCount: 10,
              thumbnailUrl: '',
            ),
          ],
          currentPage: 1,
          totalPage: 5,
        ),
      );
      when(
        () => ds.fetchPostDetail('/board/read.html?table=pds&number=42'),
      ).thenAnswer(
        (_) async => PostDetail(
          id: 42,
          title: '일관성 테스트',
          author: 'tester',
          date: DateTime(2026, 7, 28),
          contentHtml: '<p>ok</p>',
          contentBlocks: const [],
          imageUrls: const [],
          recommendCount: 1,
          notRecommendCount: 0,
          viewCount: 10,
          commentCount: 0,
          comments: const [],
        ),
      );

      final adapter = HumorunivAdapterImpl(remoteDs: ds);

      final list = await adapter.fetchLatest();
      expect(list.items.first.id, '42');

      final detail = await adapter.fetchDetail(list.items.first.id);
      expect(detail.id, 42, reason: '리스트 id와 상세 id가 일치해야 함');
      expect(detail.title, '일관성 테스트');
    });
  });
}
