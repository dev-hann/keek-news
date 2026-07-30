import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/board_post_dto.dart';

void main() {
  test('should convert BoardPostDto to BoardPost entity correctly', () {
    const dto = BoardPostDto(
      id: 12345,
      title: 'Test title',
      url: '/board/read.html?table=pds&number=12345',
      author: '작성자',
      date: '2026-05-15',
      recommendCount: 500,
      notRecommendCount: 10,
      commentCount: 42,
      viewCount: 10000,
      thumbnailUrl: 'https://img.jpg',
    );

    final entity = dto.toEntity();

    expect(entity.id, equals(12345));
    expect(entity.title, equals('Test title'));
    expect(entity.url, equals('/board/read.html?table=pds&number=12345'));
    expect(entity.author, equals('작성자'));
    expect(entity.date, equals('2026-05-15'));
    expect(entity.recommendCount, equals(500));
    expect(entity.notRecommendCount, equals(10));
    expect(entity.commentCount, equals(42));
    expect(entity.viewCount, equals(10000));
    expect(entity.thumbnailUrl, equals('https://img.jpg'));
  });

  test('should preserve all fields including zeros and empty strings', () {
    const dto = BoardPostDto(
      id: 0,
      title: '',
      url: '',
      author: '',
      date: '',
      recommendCount: 0,
      notRecommendCount: 0,
      commentCount: 0,
      viewCount: 0,
      thumbnailUrl: '',
    );

    final entity = dto.toEntity();

    expect(entity.id, equals(0));
    expect(entity.title, isEmpty);
    expect(entity.thumbnailUrl, isEmpty);
  });
}
