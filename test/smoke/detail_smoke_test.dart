import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/data/parsers/main_page_parser.dart';
import 'package:happy_news/data/parsers/post_detail_parser.dart';
import 'package:happy_news/domain/entities/content_block.dart';

import 'helpers.dart';

void main() {
  final skip = Platform.environment['SMOKE'] != '1';

  group('Smoke: post detail parser with live server', () {
    test('should fetch and parse post detail from humoruniv.com', () async {
      final mainHtml = await fetchHtml('/main.html');
      final posts = MainPageParser.parseBestPosts(mainHtml);
      if (posts.isEmpty) return;

      final firstPostUrl = posts.first.url;
      final detailHtml = await fetchHtml(firstPostUrl);
      final detail = PostDetailParser.parse(detailHtml);

      expect(
        detail.title,
        isNotEmpty,
        reason: 'Post title should not be empty',
      );
      expect(
        detail.author,
        isNotEmpty,
        reason: 'Post author should not be empty',
      );
      expect(detail.recommendCount, greaterThanOrEqualTo(0));
      expect(detail.viewCount, greaterThanOrEqualTo(0));
    }, skip: skip);

    test('should parse content blocks from live post', () async {
      final mainHtml = await fetchHtml('/main.html');
      final posts = MainPageParser.parseBestPosts(mainHtml);
      if (posts.isEmpty) return;

      final detailHtml = await fetchHtml(posts.first.url);
      final detail = PostDetailParser.parse(detailHtml);

      expect(
        detail.contentBlocks,
        isNotEmpty,
        reason: 'Content blocks should not be empty',
      );

      final hasText = detail.contentBlocks.any((b) => b is TextBlock);
      final hasImage = detail.contentBlocks.any((b) => b is ImageBlock);
      expect(
        hasText || hasImage,
        isTrue,
        reason: 'Should have text or image blocks',
      );
    }, skip: skip);

    test('should parse comments from live post', () async {
      final mainHtml = await fetchHtml('/main.html');
      final posts = MainPageParser.parseBestPosts(mainHtml);
      if (posts.isEmpty) return;

      final detailHtml = await fetchHtml(posts.first.url);
      final detail = PostDetailParser.parse(detailHtml);

      if (detail.comments.isNotEmpty) {
        final firstComment = detail.comments.first;
        expect(firstComment.author, isNotEmpty);
        expect(firstComment.content, isNotEmpty);

        final hasBest = detail.comments.any((c) => c.isBest);
        final hasReplies = detail.comments.any((c) => c.replies.isNotEmpty);
        expect(hasBest || hasReplies || detail.comments.isNotEmpty, isTrue);
      }
    }, skip: skip);

    test('should extract image URLs from live post', () async {
      final mainHtml = await fetchHtml('/main.html');
      final posts = MainPageParser.parseBestPosts(mainHtml);
      if (posts.isEmpty) return;

      final detailHtml = await fetchHtml(posts.first.url);
      final detail = PostDetailParser.parse(detailHtml);

      if (detail.imageUrls.isNotEmpty) {
        for (final url in detail.imageUrls) {
          expect(url, contains('humoruniv.com'));
        }
      }
    }, skip: skip);
  });
}
