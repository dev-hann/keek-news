import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/bookmark.dart';
import 'package:keek_news/model/community.dart';

void main() {
  group('Bookmark', () {
    test('should create with required fields and savedAt', () {
      final savedAt = DateTime(2026, 7, 30, 10);
      final bookmark = Bookmark(
        community: CommunityId.humoruniv,
        id: '100',
        title: '제목',
        url: '/board/read.html?table=pds&number=100',
        savedAt: savedAt,
      );

      expect(bookmark.community, CommunityId.humoruniv);
      expect(bookmark.id, '100');
      expect(bookmark.title, '제목');
      expect(bookmark.url, '/board/read.html?table=pds&number=100');
      expect(bookmark.author, isNull);
      expect(bookmark.thumbnailUrl, isNull);
      expect(bookmark.previewText, isNull);
      expect(bookmark.publishedAt, isNull);
      expect(bookmark.recommendCount, 0);
      expect(bookmark.commentCount, 0);
      expect(bookmark.viewCount, 0);
      expect(bookmark.savedAt, savedAt);
    });

    test('should support value equality when all fields match', () {
      final savedAt = DateTime(2026, 7, 30, 10);
      final a = Bookmark(
        community: CommunityId.humoruniv,
        id: '1',
        title: 't',
        url: 'u',
        author: 'writer',
        thumbnailUrl: 'thumb',
        previewText: 'preview',
        publishedAt: DateTime(2026, 7, 28),
        recommendCount: 5,
        commentCount: 3,
        viewCount: 100,
        savedAt: savedAt,
      );
      final b = Bookmark(
        community: CommunityId.humoruniv,
        id: '1',
        title: 't',
        url: 'u',
        author: 'writer',
        thumbnailUrl: 'thumb',
        previewText: 'preview',
        publishedAt: DateTime(2026, 7, 28),
        recommendCount: 5,
        commentCount: 3,
        viewCount: 100,
        savedAt: savedAt,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('should not be equal when community differs', () {
      final savedAt = DateTime(2026, 7, 30);
      final a = Bookmark(
        community: CommunityId.humoruniv,
        id: '1',
        title: 't',
        url: 'u',
        savedAt: savedAt,
      );
      final b = Bookmark(
        community: CommunityId.todayhumor,
        id: '1',
        title: 't',
        url: 'u',
        savedAt: savedAt,
      );

      expect(a, isNot(equals(b)));
    });

    test('should not be equal when id differs', () {
      final savedAt = DateTime(2026, 7, 30);
      final a = Bookmark(
        community: CommunityId.humoruniv,
        id: '1',
        title: 't',
        url: 'u',
        savedAt: savedAt,
      );
      final b = Bookmark(
        community: CommunityId.humoruniv,
        id: '2',
        title: 't',
        url: 'u',
        savedAt: savedAt,
      );

      expect(a, isNot(equals(b)));
    });

    test('should not be equal when savedAt differs', () {
      final a = Bookmark(
        community: CommunityId.humoruniv,
        id: '1',
        title: 't',
        url: 'u',
        savedAt: DateTime(2026, 7, 30, 10),
      );
      final b = Bookmark(
        community: CommunityId.humoruniv,
        id: '1',
        title: 't',
        url: 'u',
        savedAt: DateTime(2026, 7, 30, 11),
      );

      expect(a, isNot(equals(b)));
    });

    test('should produce stable composite key from community and id', () {
      final bookmark = Bookmark(
        community: CommunityId.dogdrip,
        id: '42',
        title: 't',
        url: 'u',
        savedAt: DateTime(2026, 7, 30),
      );

      expect(bookmark.key, 'dogdrip:42');
    });
  });
}
