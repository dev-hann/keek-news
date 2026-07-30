import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/feed_item_dto.dart';

void main() {
  group('FeedItemDto', () {
    test('toEntity should copy all fields', () {
      final dto = FeedItemDto(
        community: CommunityId.dogdrip,
        id: '42',
        title: '개드립 글',
        url: 'https://dogdrip.net/42',
        author: '개붕이',
        publishedAt: DateTime(2026, 7, 26, 10, 30),
        recommendCount: 15,
        commentCount: 3,
        viewCount: 200,
        thumbnailUrl: 'https://img.jpg',
        previewText: '미리보기',
      );

      final entity = dto.toEntity();

      expect(entity.community, CommunityId.dogdrip);
      expect(entity.id, '42');
      expect(entity.title, '개드립 글');
      expect(entity.url, 'https://dogdrip.net/42');
      expect(entity.author, '개붕이');
      expect(entity.publishedAt, DateTime(2026, 7, 26, 10, 30));
      expect(entity.recommendCount, 15);
      expect(entity.commentCount, 3);
      expect(entity.viewCount, 200);
      expect(entity.thumbnailUrl, 'https://img.jpg');
      expect(entity.previewText, '미리보기');
    });

    test('toEntity should preserve null optionals', () {
      const dto = FeedItemDto(
        community: CommunityId.humoruniv,
        id: '1',
        title: 't',
        url: 'u',
      );

      final entity = dto.toEntity();

      expect(entity.author, isNull);
      expect(entity.publishedAt, isNull);
      expect(entity.thumbnailUrl, isNull);
      expect(entity.previewText, isNull);
      expect(entity.recommendCount, 0);
    });
  });
}
