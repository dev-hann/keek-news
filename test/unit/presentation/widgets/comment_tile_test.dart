import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/domain/entities/comment.dart';
import 'package:happy_news/domain/entities/content_block.dart';
import 'package:happy_news/presentation/widgets/comment_tile.dart';

void main() {
  group('CommentTile', () {
    testWidgets('should display author and content', (tester) async {
      final comment = Comment(
        id: 1,
        author: '테스터',
        content: '댓글 내용',
        date: DateTime(2026, 5, 15),
        recommendCount: 5,
        isBest: false,
        replies: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CommentTile(comment: comment)),
        ),
      );

      expect(find.text('테스터'), findsOneWidget);
      expect(find.text('댓글 내용'), findsOneWidget);
    });

    testWidgets('should display BEST badge when isBest is true', (
      tester,
    ) async {
      final comment = Comment(
        id: 1,
        author: '테스터',
        content: '베스트 댓글',
        date: DateTime(2026, 5, 15),
        recommendCount: 100,
        isBest: true,
        replies: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CommentTile(comment: comment)),
        ),
      );

      expect(find.text('BEST'), findsOneWidget);
    });

    testWidgets('should not display BEST badge when isBest is false', (
      tester,
    ) async {
      final comment = Comment(
        id: 1,
        author: '테스터',
        content: '일반 댓글',
        date: DateTime(2026, 5, 15),
        recommendCount: 0,
        isBest: false,
        replies: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CommentTile(comment: comment)),
        ),
      );

      expect(find.text('BEST'), findsNothing);
    });

    testWidgets('should display replies', (tester) async {
      final reply = Comment(
        id: 2,
        author: '대댓글러',
        content: '대댓글 내용',
        date: DateTime(2026, 5, 15),
        recommendCount: 3,
        isBest: false,
        replies: const [],
      );
      final comment = Comment(
        id: 1,
        author: '테스터',
        content: '댓글',
        date: DateTime(2026, 5, 15),
        recommendCount: 5,
        isBest: false,
        replies: [reply],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CommentTile(comment: comment)),
        ),
      );

      expect(find.text('대댓글러'), findsOneWidget);
      expect(find.text('대댓글 내용'), findsOneWidget);
    });

    testWidgets('should not display replies section when replies is empty', (
      tester,
    ) async {
      final comment = Comment(
        id: 1,
        author: '테스터',
        content: '댓글',
        date: DateTime(2026, 5, 15),
        recommendCount: 0,
        isBest: false,
        replies: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CommentTile(comment: comment)),
        ),
      );

      expect(find.text('테스터'), findsOneWidget);
    });

    testWidgets('should display comment images when imageUrls is not empty', (
      tester,
    ) async {
      final comment = Comment(
        id: 1,
        author: '테스터',
        content: '댓글 내용',
        date: DateTime(2026, 5, 15),
        recommendCount: 5,
        isBest: false,
        mediaBlocks: const [
          ImageBlock(url: 'https://example.com/comment_img.jpg'),
        ],
        replies: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CommentTile(comment: comment)),
        ),
      );

      expect(find.text('댓글 내용'), findsOneWidget);
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
    });

    testWidgets('should not display images when imageUrls is empty', (
      tester,
    ) async {
      final comment = Comment(
        id: 1,
        author: '테스터',
        content: '댓글 내용',
        date: DateTime(2026, 5, 15),
        recommendCount: 5,
        isBest: false,
        replies: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CommentTile(comment: comment)),
        ),
      );

      expect(find.byType(Image), findsNothing);
    });

    testWidgets('should display reply images', (tester) async {
      final reply = Comment(
        id: 2,
        author: '대댓글러',
        content: '대댓글 이미지',
        date: DateTime(2026, 5, 15),
        recommendCount: 3,
        isBest: false,
        mediaBlocks: const [
          ImageBlock(url: 'https://example.com/reply_img.jpg'),
        ],
        replies: const [],
      );
      final comment = Comment(
        id: 1,
        author: '테스터',
        content: '댓글',
        date: DateTime(2026, 5, 15),
        recommendCount: 5,
        isBest: false,
        replies: [reply],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CommentTile(comment: comment)),
        ),
      );

      expect(find.text('대댓글 이미지'), findsOneWidget);
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
    });
  });
}
