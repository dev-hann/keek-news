import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/data/models/comment_dto.dart';
import 'package:happy_news/data/models/post_detail_dto.dart';

void main() {
  test('PostDetailDto should convert to PostDetail entity', () {
    final dto = PostDetailDto(
      id: 1,
      title: '제목',
      author: '작성자',
      date: DateTime(2026, 5, 15),
      contentHtml: '<p>내용</p>',
      imageUrls: ['https://img.jpg'],
      recommendCount: 86,
      notRecommendCount: 1,
      viewCount: 36000,
      commentCount: 39,
      comments: [],
    );

    final entity = dto.toEntity();

    expect(entity.id, 1);
    expect(entity.title, '제목');
    expect(entity.author, '작성자');
    expect(entity.recommendCount, 86);
    expect(entity.imageUrls, hasLength(1));
  });

  test('CommentDto should convert to Comment entity with replies', () {
    final reply = CommentDto(
      id: 2,
      author: '대댓글러',
      content: '대댓글',
      date: DateTime(2026, 5, 15),
      recommendCount: 5,
      isBest: false,
      replies: [],
    );
    final dto = CommentDto(
      id: 1,
      author: '댓글러',
      content: '댓글',
      date: DateTime(2026, 5, 15),
      recommendCount: 242,
      isBest: true,
      replies: [reply],
    );

    final entity = dto.toEntity();

    expect(entity.id, 1);
    expect(entity.isBest, isTrue);
    expect(entity.replies, hasLength(1));
    expect(entity.replies.first.author, '대댓글러');
  });

  test('CommentDto should handle isBest=false', () {
    final dto = CommentDto(
      id: 1,
      author: 'a',
      content: 'c',
      date: DateTime(2026),
      recommendCount: 0,
      isBest: false,
      replies: [],
    );

    final entity = dto.toEntity();

    expect(entity.isBest, isFalse);
  });

  test('CommentDto should handle empty replies', () {
    final dto = CommentDto(
      id: 1,
      author: 'a',
      content: 'c',
      date: DateTime(2026),
      recommendCount: 0,
      isBest: false,
      replies: [],
    );

    final entity = dto.toEntity();

    expect(entity.replies, isEmpty);
  });

  test('PostDetailDto should preserve zero counts', () {
    final dto = PostDetailDto(
      id: 0,
      title: '',
      author: '',
      date: DateTime(2026),
      contentHtml: '',
      imageUrls: [],
      recommendCount: 0,
      notRecommendCount: 0,
      viewCount: 0,
      commentCount: 0,
      comments: [],
    );

    final entity = dto.toEntity();

    expect(entity.recommendCount, 0);
    expect(entity.notRecommendCount, 0);
    expect(entity.viewCount, 0);
    expect(entity.commentCount, 0);
    expect(entity.comments, isEmpty);
    expect(entity.imageUrls, isEmpty);
  });
}
