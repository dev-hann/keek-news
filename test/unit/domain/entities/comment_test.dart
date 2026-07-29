import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/domain/entities/comment.dart';

void main() {
  group('Comment', () {
    test('should create with all required fields', () {
      final comment = Comment(
        id: 1,
        author: '작성자',
        content: '댓글',
        date: DateTime(2026, 5, 15),
        recommendCount: 42,
        isBest: true,
        replies: const [],
      );

      expect(comment.id, 1);
      expect(comment.author, '작성자');
      expect(comment.content, '댓글');
      expect(comment.recommendCount, 42);
      expect(comment.isBest, isTrue);
      expect(comment.replies, isEmpty);
    });

    test('should support value equality when all fields match', () {
      final a = Comment(
        id: 1,
        author: 'a',
        content: 'c',
        date: DateTime(2026),
        recommendCount: 0,
        isBest: false,
        replies: const [],
      );
      final b = Comment(
        id: 1,
        author: 'a',
        content: 'c',
        date: DateTime(2026),
        recommendCount: 0,
        isBest: false,
        replies: const [],
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('should not be equal when id differs', () {
      final a = Comment(
        id: 1,
        author: 'a',
        content: 'c',
        date: DateTime(2026),
        recommendCount: 0,
        isBest: false,
        replies: const [],
      );
      final b = Comment(
        id: 2,
        author: 'a',
        content: 'c',
        date: DateTime(2026),
        recommendCount: 0,
        isBest: false,
        replies: const [],
      );

      expect(a, isNot(equals(b)));
    });

    test('should not be equal when isBest differs', () {
      final a = Comment(
        id: 1,
        author: 'a',
        content: 'c',
        date: DateTime(2026),
        recommendCount: 0,
        isBest: true,
        replies: const [],
      );
      final b = Comment(
        id: 1,
        author: 'a',
        content: 'c',
        date: DateTime(2026),
        recommendCount: 0,
        isBest: false,
        replies: const [],
      );

      expect(a, isNot(equals(b)));
    });

    test('should not be equal when replies differ', () {
      final reply = Comment(
        id: 99,
        author: 'r',
        content: 'r',
        date: DateTime(2026),
        recommendCount: 0,
        isBest: false,
        replies: const [],
      );
      final a = Comment(
        id: 1,
        author: 'a',
        content: 'c',
        date: DateTime(2026),
        recommendCount: 0,
        isBest: false,
        replies: [reply],
      );
      final b = Comment(
        id: 1,
        author: 'a',
        content: 'c',
        date: DateTime(2026),
        recommendCount: 0,
        isBest: false,
        replies: const [],
      );

      expect(a, isNot(equals(b)));
    });

    test('should support deeply nested replies', () {
      final level2 = Comment(
        id: 3,
        author: 'l2',
        content: 'l2',
        date: DateTime(2026),
        recommendCount: 0,
        isBest: false,
        replies: const [],
      );
      final level1 = Comment(
        id: 2,
        author: 'l1',
        content: 'l1',
        date: DateTime(2026),
        recommendCount: 0,
        isBest: false,
        replies: [level2],
      );
      final root = Comment(
        id: 1,
        author: 'root',
        content: 'root',
        date: DateTime(2026),
        recommendCount: 0,
        isBest: false,
        replies: [level1],
      );

      expect(root.replies.first.replies.first.author, 'l2');
    });

    test('should not be equal when content differs', () {
      final a = Comment(
        id: 1,
        author: 'a',
        content: 'x',
        date: DateTime(2026),
        recommendCount: 0,
        isBest: false,
        replies: const [],
      );
      final b = Comment(
        id: 1,
        author: 'a',
        content: 'y',
        date: DateTime(2026),
        recommendCount: 0,
        isBest: false,
        replies: const [],
      );

      expect(a, isNot(equals(b)));
    });

    test('should be equal to itself', () {
      final a = Comment(
        id: 1,
        author: 'a',
        content: 'c',
        date: DateTime(2026),
        recommendCount: 0,
        isBest: false,
        replies: const [],
      );

      expect(a, equals(a));
    });

    test('should not be equal to non-Comment', () {
      final a = Comment(
        id: 1,
        author: 'a',
        content: 'c',
        date: DateTime(2026),
        recommendCount: 0,
        isBest: false,
        replies: const [],
      );

      expect(a, isNot(equals('not a comment')));
    });

    test('should handle list equality with different lengths', () {
      final reply = Comment(
        id: 99,
        author: 'r',
        content: 'r',
        date: DateTime(2026),
        recommendCount: 0,
        isBest: false,
        replies: const [],
      );
      final a = Comment(
        id: 1,
        author: 'a',
        content: 'c',
        date: DateTime(2026),
        recommendCount: 0,
        isBest: false,
        replies: [reply, reply],
      );
      final b = Comment(
        id: 1,
        author: 'a',
        content: 'c',
        date: DateTime(2026),
        recommendCount: 0,
        isBest: false,
        replies: [reply],
      );

      expect(a, isNot(equals(b)));
    });
  });
}
