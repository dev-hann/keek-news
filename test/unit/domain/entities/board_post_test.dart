import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/domain/entities/board_post.dart';
import 'package:happy_news/domain/entities/community.dart';

void main() {
  group('BoardPost', () {
    test('should create with all required fields', () {
      const post = BoardPost(
        id: 100,
        title: '테스트 게시글',
        url: '/board/read.html?table=pds&number=100',
        author: '작성자',
        date: '2026-05-15',
        recommendCount: 42,
        notRecommendCount: 1,
        commentCount: 10,
        viewCount: 500,
        thumbnailUrl: 'https://img.jpg',
      );

      expect(post.id, 100);
      expect(post.title, '테스트 게시글');
      expect(post.url, '/board/read.html?table=pds&number=100');
      expect(post.author, '작성자');
      expect(post.date, '2026-05-15');
      expect(post.recommendCount, 42);
      expect(post.notRecommendCount, 1);
      expect(post.commentCount, 10);
      expect(post.viewCount, 500);
      expect(post.thumbnailUrl, 'https://img.jpg');
    });

    test('should support value equality when all fields match', () {
      const a = BoardPost(
        id: 1,
        title: 't',
        url: 'u',
        author: 'a',
        date: 'd',
        recommendCount: 0,
        notRecommendCount: 0,
        commentCount: 0,
        viewCount: 0,
        thumbnailUrl: '',
      );
      const b = BoardPost(
        id: 1,
        title: 't',
        url: 'u',
        author: 'a',
        date: 'd',
        recommendCount: 0,
        notRecommendCount: 0,
        commentCount: 0,
        viewCount: 0,
        thumbnailUrl: '',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('should not be equal when id differs', () {
      const a = BoardPost(
        id: 1,
        title: 't',
        url: 'u',
        author: 'a',
        date: 'd',
        recommendCount: 0,
        notRecommendCount: 0,
        commentCount: 0,
        viewCount: 0,
        thumbnailUrl: '',
      );
      const b = BoardPost(
        id: 2,
        title: 't',
        url: 'u',
        author: 'a',
        date: 'd',
        recommendCount: 0,
        notRecommendCount: 0,
        commentCount: 0,
        viewCount: 0,
        thumbnailUrl: '',
      );

      expect(a, isNot(equals(b)));
    });

    test('should not be equal when thumbnailUrl differs', () {
      const a = BoardPost(
        id: 1,
        title: 't',
        url: 'u',
        author: 'a',
        date: 'd',
        recommendCount: 0,
        notRecommendCount: 0,
        commentCount: 0,
        viewCount: 0,
        thumbnailUrl: 'thumb1',
      );
      const b = BoardPost(
        id: 1,
        title: 't',
        url: 'u',
        author: 'a',
        date: 'd',
        recommendCount: 0,
        notRecommendCount: 0,
        commentCount: 0,
        viewCount: 0,
        thumbnailUrl: 'thumb2',
      );

      expect(a, isNot(equals(b)));
    });

    test('should handle empty thumbnailUrl', () {
      const post = BoardPost(
        id: 1,
        title: 't',
        url: 'u',
        author: 'a',
        date: 'd',
        recommendCount: 0,
        notRecommendCount: 0,
        commentCount: 0,
        viewCount: 0,
        thumbnailUrl: '',
      );

      expect(post.thumbnailUrl, isEmpty);
    });

    test('should not be equal to non-BoardPost', () {
      const a = BoardPost(
        id: 1,
        title: 't',
        url: 'u',
        author: 'a',
        date: 'd',
        recommendCount: 0,
        notRecommendCount: 0,
        commentCount: 0,
        viewCount: 0,
        thumbnailUrl: '',
      );

      expect(a, isNot(equals('not a post')));
    });

    test('previewText should default to null when not provided', () {
      const post = BoardPost(
        id: 1,
        title: 't',
        url: 'u',
        author: 'a',
        date: 'd',
        recommendCount: 0,
        notRecommendCount: 0,
        commentCount: 0,
        viewCount: 0,
        thumbnailUrl: '',
      );
      expect(post.previewText, isNull);
    });

    test('should allow optional previewText', () {
      const post = BoardPost(
        id: 1,
        title: 't',
        url: 'u',
        author: 'a',
        date: 'd',
        recommendCount: 0,
        notRecommendCount: 0,
        commentCount: 0,
        viewCount: 0,
        thumbnailUrl: '',
        previewText: '미리보기',
      );
      expect(post.previewText, '미리보기');
    });

    test('should not be equal when previewText differs', () {
      const a = BoardPost(
        id: 1,
        title: 't',
        url: 'u',
        author: 'a',
        date: 'd',
        recommendCount: 0,
        notRecommendCount: 0,
        commentCount: 0,
        viewCount: 0,
        thumbnailUrl: '',
        previewText: 'a',
      );
      const b = BoardPost(
        id: 1,
        title: 't',
        url: 'u',
        author: 'a',
        date: 'd',
        recommendCount: 0,
        notRecommendCount: 0,
        commentCount: 0,
        viewCount: 0,
        thumbnailUrl: '',
        previewText: 'b',
      );
      expect(a, isNot(equals(b)));
    });

    test('should default community to humoruniv', () {
      const post = BoardPost(
        id: 1,
        title: 't',
        url: 'u',
        author: 'a',
        date: '2026-07-26',
        recommendCount: 0,
        notRecommendCount: 0,
        commentCount: 0,
        viewCount: 0,
        thumbnailUrl: '',
      );
      expect(post.community, CommunityId.humoruniv);
    });

    test('should not be equal when community differs', () {
      const a = BoardPost(
        id: 1,
        title: 't',
        url: 'u',
        author: 'a',
        date: 'd',
        recommendCount: 0,
        notRecommendCount: 0,
        commentCount: 0,
        viewCount: 0,
        thumbnailUrl: '',
      );
      const b = BoardPost(
        id: 1,
        title: 't',
        url: 'u',
        author: 'a',
        date: 'd',
        recommendCount: 0,
        notRecommendCount: 0,
        commentCount: 0,
        viewCount: 0,
        thumbnailUrl: '',
        community: CommunityId.ppomppu,
      );
      expect(a, isNot(equals(b)));
    });
  });
}
