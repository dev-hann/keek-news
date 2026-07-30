import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/bookmark.dart';
import 'package:keek_news/model/bookmark_dto.dart';
import 'package:keek_news/model/community.dart';

void main() {
  group('BookmarkDto', () {
    test('toEntity should produce equivalent Bookmark', () {
      const dto = BookmarkDto(
        community: CommunityId.humoruniv,
        id: '100',
        title: '제목',
        url: '/board/read.html?table=pds&number=100',
        author: 'writer',
        thumbnailUrl: 'thumb',
        previewText: 'preview',
        publishedAtMillis: 1722064800000,
        recommendCount: 5,
        commentCount: 3,
        viewCount: 100,
        savedAtMillis: 1722324000000,
      );

      final entity = dto.toEntity();

      expect(entity.community, CommunityId.humoruniv);
      expect(entity.id, '100');
      expect(entity.title, '제목');
      expect(entity.url, '/board/read.html?table=pds&number=100');
      expect(entity.author, 'writer');
      expect(entity.thumbnailUrl, 'thumb');
      expect(entity.previewText, 'preview');
      expect(
        entity.publishedAt,
        DateTime.fromMillisecondsSinceEpoch(1722064800000),
      );
      expect(entity.recommendCount, 5);
      expect(entity.commentCount, 3);
      expect(entity.viewCount, 100);
      expect(
        entity.savedAt,
        DateTime.fromMillisecondsSinceEpoch(1722324000000),
      );
    });

    test('toEntity should handle nullable fields as null', () {
      const dto = BookmarkDto(
        community: CommunityId.humoruniv,
        id: '1',
        title: 't',
        url: 'u',
        savedAtMillis: 1722324000000,
      );

      final entity = dto.toEntity();

      expect(entity.author, isNull);
      expect(entity.thumbnailUrl, isNull);
      expect(entity.previewText, isNull);
      expect(entity.publishedAt, isNull);
    });

    test('fromJson should parse complete JSON', () {
      final json = <String, dynamic>{
        'community': 'humoruniv',
        'id': '100',
        'title': '제목',
        'url': '/url',
        'author': 'writer',
        'thumbnailUrl': 'thumb',
        'previewText': 'preview',
        'publishedAtMillis': 1722064800000,
        'recommendCount': 5,
        'commentCount': 3,
        'viewCount': 100,
        'savedAtMillis': 1722324000000,
      };

      final dto = BookmarkDto.fromJson(json);

      expect(dto.community, CommunityId.humoruniv);
      expect(dto.id, '100');
      expect(dto.title, '제목');
      expect(dto.url, '/url');
      expect(dto.author, 'writer');
      expect(dto.thumbnailUrl, 'thumb');
      expect(dto.previewText, 'preview');
      expect(dto.publishedAtMillis, 1722064800000);
      expect(dto.recommendCount, 5);
      expect(dto.commentCount, 3);
      expect(dto.viewCount, 100);
      expect(dto.savedAtMillis, 1722324000000);
    });

    test('fromJson should default missing optional fields', () {
      final json = <String, dynamic>{
        'community': 'dogdrip',
        'id': '42',
        'title': 't',
        'url': 'u',
        'savedAtMillis': 1722324000000,
      };

      final dto = BookmarkDto.fromJson(json);

      expect(dto.author, isNull);
      expect(dto.thumbnailUrl, isNull);
      expect(dto.previewText, isNull);
      expect(dto.publishedAtMillis, isNull);
      expect(dto.recommendCount, 0);
      expect(dto.commentCount, 0);
      expect(dto.viewCount, 0);
    });

    test('toJson should produce JSON map', () {
      const dto = BookmarkDto(
        community: CommunityId.humoruniv,
        id: '100',
        title: '제목',
        url: '/url',
        author: 'writer',
        thumbnailUrl: 'thumb',
        previewText: 'preview',
        publishedAtMillis: 1722064800000,
        recommendCount: 5,
        commentCount: 3,
        viewCount: 100,
        savedAtMillis: 1722324000000,
      );

      final json = dto.toJson();

      expect(json['community'], 'humoruniv');
      expect(json['id'], '100');
      expect(json['title'], '제목');
      expect(json['url'], '/url');
      expect(json['author'], 'writer');
      expect(json['thumbnailUrl'], 'thumb');
      expect(json['previewText'], 'preview');
      expect(json['publishedAtMillis'], 1722064800000);
      expect(json['recommendCount'], 5);
      expect(json['commentCount'], 3);
      expect(json['viewCount'], 100);
      expect(json['savedAtMillis'], 1722324000000);
    });

    test('toJson/fromJson round-trip should preserve data', () {
      const original = BookmarkDto(
        community: CommunityId.todayhumor,
        id: '7',
        title: 't',
        url: 'u',
        author: 'a',
        thumbnailUrl: 'th',
        previewText: 'p',
        publishedAtMillis: 1722000000000,
        recommendCount: 1,
        commentCount: 2,
        viewCount: 3,
        savedAtMillis: 1722324000000,
      );

      final roundTripped = BookmarkDto.fromJson(original.toJson());

      expect(roundTripped.community, original.community);
      expect(roundTripped.id, original.id);
      expect(roundTripped.title, original.title);
      expect(roundTripped.url, original.url);
      expect(roundTripped.author, original.author);
      expect(roundTripped.thumbnailUrl, original.thumbnailUrl);
      expect(roundTripped.previewText, original.previewText);
      expect(roundTripped.publishedAtMillis, original.publishedAtMillis);
      expect(roundTripped.recommendCount, original.recommendCount);
      expect(roundTripped.commentCount, original.commentCount);
      expect(roundTripped.viewCount, original.viewCount);
      expect(roundTripped.savedAtMillis, original.savedAtMillis);
    });

    test('fromEntity should build DTO from Bookmark', () {
      final bookmark = Bookmark(
        community: CommunityId.humoruniv,
        id: '100',
        title: '제목',
        url: '/url',
        author: 'writer',
        thumbnailUrl: 'thumb',
        previewText: 'preview',
        publishedAt: DateTime.fromMillisecondsSinceEpoch(1722064800000),
        recommendCount: 5,
        commentCount: 3,
        viewCount: 100,
        savedAt: DateTime.fromMillisecondsSinceEpoch(1722324000000),
      );

      final dto = BookmarkDto.fromEntity(bookmark);

      expect(dto.community, CommunityId.humoruniv);
      expect(dto.id, '100');
      expect(dto.title, '제목');
      expect(dto.url, '/url');
      expect(dto.author, 'writer');
      expect(dto.thumbnailUrl, 'thumb');
      expect(dto.previewText, 'preview');
      expect(dto.publishedAtMillis, 1722064800000);
      expect(dto.recommendCount, 5);
      expect(dto.commentCount, 3);
      expect(dto.viewCount, 100);
      expect(dto.savedAtMillis, 1722324000000);
    });

    test(
      'full round-trip: entity -> dto -> json -> dto -> entity should be equal',
      () {
        final original = Bookmark(
          community: CommunityId.ppomppu,
          id: '9',
          title: 'title',
          url: 'url',
          author: 'auth',
          thumbnailUrl: 'thumb',
          previewText: 'prev',
          publishedAt: DateTime.fromMillisecondsSinceEpoch(1722000000000),
          recommendCount: 10,
          commentCount: 20,
          viewCount: 30,
          savedAt: DateTime.fromMillisecondsSinceEpoch(1722324000000),
        );

        final roundTripped = BookmarkDto.fromJson(
          BookmarkDto.fromEntity(original).toJson(),
        ).toEntity();

        expect(roundTripped.community, original.community);
        expect(roundTripped.id, original.id);
        expect(roundTripped.title, original.title);
        expect(roundTripped.url, original.url);
        expect(roundTripped.author, original.author);
        expect(roundTripped.thumbnailUrl, original.thumbnailUrl);
        expect(roundTripped.previewText, original.previewText);
        expect(
          roundTripped.publishedAt?.millisecondsSinceEpoch,
          original.publishedAt!.millisecondsSinceEpoch,
        );
        expect(roundTripped.recommendCount, original.recommendCount);
        expect(roundTripped.commentCount, original.commentCount);
        expect(roundTripped.viewCount, original.viewCount);
        expect(
          roundTripped.savedAt.millisecondsSinceEpoch,
          original.savedAt.millisecondsSinceEpoch,
        );
      },
    );
  });
}
