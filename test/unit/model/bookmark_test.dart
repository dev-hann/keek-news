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

  group('Bookmark.fromJson', () {
    test('should deserialize all fields', () {
      final json = <String, dynamic>{
        'community': 'humoruniv',
        'id': '100',
        'title': '제목',
        'url': '/u',
        'savedAtMillis': 1722324000000,
        'author': 'writer',
        'thumbnailUrl': 'thumb',
        'previewText': 'preview',
        'publishedAtMillis': 1722240000000,
        'recommendCount': 5,
        'commentCount': 3,
        'viewCount': 100,
      };

      final b = Bookmark.fromJson(json);

      expect(b.community, CommunityId.humoruniv);
      expect(b.id, '100');
      expect(b.title, '제목');
      expect(b.url, '/u');
      expect(b.savedAt.millisecondsSinceEpoch, 1722324000000);
      expect(b.author, 'writer');
      expect(b.thumbnailUrl, 'thumb');
      expect(b.previewText, 'preview');
      expect(b.publishedAt!.millisecondsSinceEpoch, 1722240000000);
      expect(b.recommendCount, 5);
      expect(b.commentCount, 3);
      expect(b.viewCount, 100);
    });

    test('should default counts to 0 when missing', () {
      final b = Bookmark.fromJson({
        'community': 'humoruniv',
        'id': '1',
        'title': 't',
        'url': 'u',
        'savedAtMillis': 0,
      });

      expect(b.recommendCount, 0);
      expect(b.commentCount, 0);
      expect(b.viewCount, 0);
      expect(b.publishedAt, isNull);
    });

    test('should round-trip via toJson', () {
      final original = Bookmark(
        community: CommunityId.dogdrip,
        id: '42',
        title: 't',
        url: 'u',
        author: 'w',
        thumbnailUrl: 'th',
        previewText: 'pv',
        publishedAt: DateTime(2026, 7, 28),
        recommendCount: 5,
        commentCount: 3,
        viewCount: 10,
        savedAt: DateTime(2026, 7, 30),
      );

      final roundTripped = Bookmark.fromJson(original.toJson());

      expect(roundTripped, original);
    });
  });
}
