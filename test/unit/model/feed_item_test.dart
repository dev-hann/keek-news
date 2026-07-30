import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/feed_item.dart';

void main() {
  group('FeedItem', () {
    test('should create with required fields and sensible defaults', () {
      const item = FeedItem(
        community: CommunityId.humoruniv,
        id: '100',
        title: '제목',
        url: '/board/read.html?table=pds&number=100',
      );

      expect(item.community, CommunityId.humoruniv);
      expect(item.id, '100');
      expect(item.title, '제목');
      expect(item.url, '/board/read.html?table=pds&number=100');
      expect(item.author, isNull);
      expect(item.publishedAt, isNull);
      expect(item.recommendCount, 0);
      expect(item.commentCount, 0);
      expect(item.viewCount, 0);
      expect(item.thumbnailUrl, isNull);
      expect(item.previewText, isNull);
    });

    test('should support value equality when all fields match', () {
      final a = FeedItem(
        community: CommunityId.humoruniv,
        id: '1',
        title: 't',
        url: 'u',
        author: 'writer',
        publishedAt: DateTime(2026, 7, 26),
        recommendCount: 5,
      );
      final b = FeedItem(
        community: CommunityId.humoruniv,
        id: '1',
        title: 't',
        url: 'u',
        author: 'writer',
        publishedAt: DateTime(2026, 7, 26),
        recommendCount: 5,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('should not be equal when community differs', () {
      const a = FeedItem(
        community: CommunityId.humoruniv,
        id: '1',
        title: 't',
        url: 'u',
      );
      const b = FeedItem(
        community: CommunityId.todayhumor,
        id: '1',
        title: 't',
        url: 'u',
      );

      expect(a, isNot(equals(b)));
    });

    test('should not be equal when id differs', () {
      const a = FeedItem(
        community: CommunityId.humoruniv,
        id: '1',
        title: 't',
        url: 'u',
      );
      const b = FeedItem(
        community: CommunityId.humoruniv,
        id: '2',
        title: 't',
        url: 'u',
      );

      expect(a, isNot(equals(b)));
    });
  });
}
