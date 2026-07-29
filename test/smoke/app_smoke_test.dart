import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/data/parsers/main_page_parser.dart';

import 'helpers.dart';

void main() {
  final skip = Platform.environment['SMOKE'] != '1';

  group('Smoke: main page parser with live server', () {
    test('should fetch and parse best posts from humoruniv.com', () async {
      final html = await fetchHtml('/main.html');
      final posts = MainPageParser.parseBestPosts(html);

      expect(posts, isNotEmpty, reason: 'Best posts should not be empty');
      expect(
        posts.length,
        greaterThanOrEqualTo(5),
        reason: 'Should have at least 5 best posts',
      );

      for (final post in posts) {
        expect(post.id, greaterThan(0), reason: 'Post id should be positive');
        expect(
          post.title,
          isNotEmpty,
          reason: 'Post title should not be empty',
        );
        expect(post.recommendCount, greaterThanOrEqualTo(0));
        expect(
          post.url,
          contains('number='),
          reason: 'Post url should contain number param',
        );
      }
    }, skip: skip);

    test('should have valid post URLs that can be fetched', () async {
      final html = await fetchHtml('/main.html');
      final posts = MainPageParser.parseBestPosts(html);
      if (posts.isEmpty) return;

      final firstPostHtml = await fetchHtml(posts.first.url);

      expect(firstPostHtml, isNotEmpty);
    }, skip: skip);
  });
}
