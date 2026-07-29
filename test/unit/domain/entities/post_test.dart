import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/domain/entities/community.dart';
import 'package:happy_news/domain/entities/post.dart';

void main() {
  group('Post', () {
    test('should create with required fields', () {
      const post = Post(
        id: 100,
        title: '테스트 게시글',
        recommendCount: 42,
        url: '/board/read.html?table=pds&number=100',
      );

      expect(post.id, 100);
      expect(post.title, '테스트 게시글');
      expect(post.recommendCount, 42);
      expect(post.url, '/board/read.html?table=pds&number=100');
    });

    test('should support value equality when all fields match', () {
      const a = Post(id: 1, title: 't', recommendCount: 0, url: 'u');
      const b = Post(id: 1, title: 't', recommendCount: 0, url: 'u');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('should not be equal when id differs', () {
      const a = Post(id: 1, title: 't', recommendCount: 0, url: 'u');
      const b = Post(id: 2, title: 't', recommendCount: 0, url: 'u');

      expect(a, isNot(equals(b)));
    });

    test('should not be equal when title differs', () {
      const a = Post(id: 1, title: 'a', recommendCount: 0, url: 'u');
      const b = Post(id: 1, title: 'b', recommendCount: 0, url: 'u');

      expect(a, isNot(equals(b)));
    });

    test('should not be equal when recommendCount differs', () {
      const a = Post(id: 1, title: 't', recommendCount: 0, url: 'u');
      const b = Post(id: 1, title: 't', recommendCount: 1, url: 'u');

      expect(a, isNot(equals(b)));
    });

    test('should not be equal when url differs', () {
      const a = Post(id: 1, title: 't', recommendCount: 0, url: 'a');
      const b = Post(id: 1, title: 't', recommendCount: 0, url: 'b');

      expect(a, isNot(equals(b)));
    });

    test('should not be equal to non-Post object', () {
      const a = Post(id: 1, title: 't', recommendCount: 0, url: 'u');

      expect(a, isNot(equals('not a post')));
      expect(a, isNot(equals(42)));
    });

    test('should be equal to itself (identical)', () {
      const a = Post(id: 1, title: 't', recommendCount: 0, url: 'u');

      expect(a, equals(a));
    });

    test('should default community to humoruniv', () {
      const post = Post(id: 1, title: 't', recommendCount: 0, url: 'u');
      expect(post.community, CommunityId.humoruniv);
    });

    test('should allow community to be set explicitly', () {
      const post = Post(
        id: 1,
        title: 't',
        recommendCount: 0,
        url: 'u',
        community: CommunityId.todayhumor,
      );
      expect(post.community, CommunityId.todayhumor);
    });

    test('should not be equal when community differs', () {
      const a = Post(
        id: 1,
        title: 't',
        recommendCount: 0,
        url: 'u',
        community: CommunityId.humoruniv,
      );
      const b = Post(
        id: 1,
        title: 't',
        recommendCount: 0,
        url: 'u',
        community: CommunityId.todayhumor,
      );
      expect(a, isNot(equals(b)));
    });
  });
}
