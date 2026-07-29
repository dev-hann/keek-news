import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/domain/entities/board_list_result.dart';
import 'package:happy_news/domain/entities/board_post.dart';

void main() {
  group('BoardListResult', () {
    test('should be equal when all fields match', () {
      const posts = [
        BoardPost(
          id: 1,
          title: 'Test',
          url: '/test',
          author: 'user',
          date: '2026-01-01',
          recommendCount: 10,
          notRecommendCount: 0,
          commentCount: 5,
          viewCount: 100,
          thumbnailUrl: '',
        ),
      ];
      const a = BoardListResult(posts: posts, currentPage: 0, totalPage: 5);
      const b = BoardListResult(posts: posts, currentPage: 0, totalPage: 5);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('should not be equal when fields differ', () {
      const a = BoardListResult(posts: [], currentPage: 0, totalPage: 5);
      const b = BoardListResult(posts: [], currentPage: 1, totalPage: 5);

      expect(a, isNot(equals(b)));
    });

    test('should not be equal when posts differ', () {
      const postA = [
        BoardPost(
          id: 1,
          title: 'A',
          url: '/a',
          author: 'user',
          date: '2026-01-01',
          recommendCount: 0,
          notRecommendCount: 0,
          commentCount: 0,
          viewCount: 0,
          thumbnailUrl: '',
        ),
      ];
      const postB = [
        BoardPost(
          id: 2,
          title: 'B',
          url: '/b',
          author: 'user',
          date: '2026-01-01',
          recommendCount: 0,
          notRecommendCount: 0,
          commentCount: 0,
          viewCount: 0,
          thumbnailUrl: '',
        ),
      ];
      const a = BoardListResult(posts: postA, currentPage: 0, totalPage: 5);
      const b = BoardListResult(posts: postB, currentPage: 0, totalPage: 5);

      expect(a, isNot(equals(b)));
    });

    test('should be equal to itself', () {
      const result = BoardListResult(posts: [], currentPage: 0, totalPage: 0);
      expect(result, equals(result));
    });

    test('should not be equal to non-BoardListResult', () {
      const result = BoardListResult(posts: [], currentPage: 0, totalPage: 0);
      expect(result, isNot(equals('not a result')));
    });
  });
}
