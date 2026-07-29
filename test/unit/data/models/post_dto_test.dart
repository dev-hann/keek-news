import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/data/models/post_dto.dart';
import 'package:happy_news/domain/entities/post.dart';

void main() {
  test('should convert PostDto to Post entity correctly', () {
    const dto = PostDto(
      id: 12345,
      title: 'Test title',
      recommendCount: 500,
      url: '/board/read.html?table=pds&number=12345',
    );

    final entity = dto.toEntity();

    expect(entity, isA<Post>());
    expect(entity.id, equals(12345));
    expect(entity.title, equals('Test title'));
    expect(entity.recommendCount, equals(500));
    expect(entity.url, equals('/board/read.html?table=pds&number=12345'));
  });

  test('should preserve all fields during conversion', () {
    const dto = PostDto(id: 1, title: '', recommendCount: 0, url: '');

    final entity = dto.toEntity();

    expect(entity.id, equals(1));
    expect(entity.title, isEmpty);
    expect(entity.recommendCount, equals(0));
    expect(entity.url, isEmpty);
  });
}
