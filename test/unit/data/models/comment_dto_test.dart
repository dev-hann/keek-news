import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/data/models/comment_dto.dart';
import 'package:happy_news/domain/entities/content_block.dart';

void main() {
  group('CommentDto', () {
    test('should convert to Comment entity with no replies', () {
      final dto = CommentDto(
        id: 1,
        author: 'user',
        content: 'comment',
        date: DateTime(2026, 5, 15),
        recommendCount: 10,
        isBest: false,
        replies: [],
      );

      final entity = dto.toEntity();

      expect(entity.id, 1);
      expect(entity.replies, isEmpty);
    });

    test('should convert deeply nested replies', () {
      final level2 = CommentDto(
        id: 3,
        author: 'l2',
        content: 'level 2',
        date: DateTime(2026),
        recommendCount: 0,
        isBest: false,
        replies: [],
      );
      final level1 = CommentDto(
        id: 2,
        author: 'l1',
        content: 'level 1',
        date: DateTime(2026),
        recommendCount: 1,
        isBest: false,
        replies: [level2],
      );
      final root = CommentDto(
        id: 1,
        author: 'root',
        content: 'root',
        date: DateTime(2026),
        recommendCount: 5,
        isBest: true,
        replies: [level1],
      );

      final entity = root.toEntity();

      expect(entity.replies, hasLength(1));
      expect(entity.replies.first.replies, hasLength(1));
      expect(entity.replies.first.replies.first.author, 'l2');
    });

    test('should preserve isBest flag', () {
      final dto = CommentDto(
        id: 1,
        author: 'a',
        content: 'c',
        date: DateTime(2026),
        recommendCount: 100,
        isBest: true,
        replies: [],
      );

      expect(dto.toEntity().isBest, isTrue);
    });

    test('should preserve all numeric fields', () {
      final dto = CommentDto(
        id: 42,
        author: 'a',
        content: 'c',
        date: DateTime(2026),
        recommendCount: 999,
        isBest: false,
        replies: [],
      );

      final entity = dto.toEntity();

      expect(entity.id, 42);
      expect(entity.recommendCount, 999);
    });

    test('should preserve mediaBlocks when converting to entity', () {
      final dto = CommentDto(
        id: 1,
        author: 'a',
        content: 'c',
        date: DateTime(2026),
        recommendCount: 0,
        isBest: false,
        replies: [],
        mediaBlocks: [
          const ImageBlock(url: 'https://example.com/img.jpg'),
          const VideoBlock(url: 'https://example.com/v.mp4'),
        ],
      );

      final entity = dto.toEntity();

      expect(entity.mediaBlocks, hasLength(2));
      expect(entity.mediaBlocks.whereType<ImageBlock>(), hasLength(1));
      expect(entity.mediaBlocks.whereType<VideoBlock>(), hasLength(1));
      expect(entity.imageUrls, ['https://example.com/img.jpg']);
    });
  });
}
