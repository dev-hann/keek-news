import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/data/parsers/todayhumor_list_parser.dart';
import 'package:happy_news/domain/entities/community.dart';

void main() {
  late String html;

  setUpAll(() {
    html = File(
      'test/fixtures/todayhumor/list_humorbest_pc.html',
    ).readAsStringSync();
  });

  group('TodayhumorListParser', () {
    test('should parse posts from valid HTML', () {
      final result = TodayhumorListParser.parse(html);

      expect(result, isNotEmpty);
    });

    test('should extract id, title, url from first post', () {
      final result = TodayhumorListParser.parse(html);
      final first = result.first;

      expect(first.community, CommunityId.todayhumor);
      expect(first.id, isNotEmpty);
      expect(first.title, isNotEmpty);
      expect(first.url, contains('view.php'));
    });

    test('should extract author name', () {
      final result = TodayhumorListParser.parse(html);

      for (final post in result) {
        expect(post.author, isNotEmpty);
      }
    });

    test('should parse date into DateTime', () {
      final result = TodayhumorListParser.parse(html);
      final first = result.first;

      expect(first.publishedAt, isNotNull);
      expect(first.publishedAt!.year, greaterThanOrEqualTo(2026));
    });

    test('should parse view and recommend counts', () {
      final result = TodayhumorListParser.parse(html);
      final first = result.first;

      expect(first.viewCount, greaterThan(0));
      expect(first.recommendCount, greaterThan(0));
    });

    test('should parse comment count from [N] notation', () {
      final result = TodayhumorListParser.parse(html);
      final first = result.first;

      expect(first.commentCount, greaterThanOrEqualTo(0));
    });

    test('should return empty list for empty HTML', () {
      expect(TodayhumorListParser.parse(''), isEmpty);
    });

    test('should return empty list for HTML without post rows', () {
      expect(
        TodayhumorListParser.parse('<html><body>no posts</body></html>'),
        isEmpty,
      );
    });
  });
}
