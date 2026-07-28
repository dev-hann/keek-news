import 'package:flutter_test/flutter_test.dart';
import 'package:humoruniv/data/datasources/community_adapter.dart';
import 'package:humoruniv/data/datasources/humoruniv_adapter_impl.dart';
import 'package:humoruniv/data/datasources/humoruniv_remote_ds.dart';
import 'package:humoruniv/data/models/post_dto.dart';
import 'package:humoruniv/domain/entities/comment.dart';
import 'package:humoruniv/domain/entities/community.dart';
import 'package:humoruniv/domain/entities/content_block.dart';
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

    test('fetchLatest should delegate to fetchMainPage and convert PostDto to FeedItemDto', () async {
      when(() => mockDs.fetchMainPage()).thenAnswer((_) async => [
            const PostDto(id: 100, title: '첫 글', recommendCount: 42, url: '/board/read.html?table=pds&number=100'),
            const PostDto(id: 200, title: '둘', recommendCount: 7, url: '/board/read.html?table=pds&number=200'),
          ]);

      final result = await adapter.fetchLatest();

      expect(result.items, hasLength(2));
      expect(result.items[0].community, CommunityId.humoruniv);
      expect(result.items[0].id, '100');
      expect(result.items[0].title, '첫 글');
      expect(result.items[0].recommendCount, 42);
      expect(result.items[0].url, '/board/read.html?table=pds&number=100');
      expect(result.items[1].id, '200');
    });

    test('fetchLatest should return empty list when fetchMainPage returns empty', () async {
      when(() => mockDs.fetchMainPage()).thenAnswer((_) async => []);

      final result = await adapter.fetchLatest();

      expect(result.items, isEmpty);
    });

    test('fetchDetail should delegate to fetchPostDetail and return PostDetail', () async {
      const url = '/board/read.html?table=pds&number=100';
      final detail = PostDetail(
        id: 100,
        title: '제목',
        author: '작성자',
        date: DateTime(2026, 7, 26),
        contentHtml: '<p>내용</p>',
        contentBlocks: const [],
        imageUrls: const ['https://img.jpg'],
        recommendCount: 10,
        notRecommendCount: 1,
        viewCount: 500,
        commentCount: 3,
        comments: const [],
      );
      when(() => mockDs.fetchPostDetail(any())).thenAnswer((_) async => detail);

      final result = await adapter.fetchDetail(url);

      expect(result.id, 100);
      expect(result.title, '제목');
      expect(result.author, '작성자');
      expect(result.recommendCount, 10);
      expect(result.imageUrls, hasLength(1));
    });

    test('healthCheck should return true when fetchMainPage succeeds', () async {
      when(() => mockDs.fetchMainPage()).thenAnswer((_) async => []);

      final healthy = await adapter.healthCheck();

      expect(healthy, isTrue);
    });

    test('healthCheck should return false when fetchMainPage throws', () async {
      when(() => mockDs.fetchMainPage()).thenThrow(Exception('network error'));

      final healthy = await adapter.healthCheck();

      expect(healthy, isFalse);
    });
  });
}
