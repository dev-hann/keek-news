import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/service/parser/ppomppu_detail_parser.dart';

void main() {
  late String html;
  late String htmlWithComments;

  setUpAll(() {
    html = File('test/fixtures/ppomppu/detail_770409.html').readAsStringSync();
    htmlWithComments = File(
      'test/fixtures/ppomppu/detail_with_comments.html',
    ).readAsStringSync();
  });

  group('PpomppuDetailParser', () {
    test('should parse title', () {
      final result = PpomppuDetailParser.parse(html);
      expect(result.title, contains('하이닉스'));
    });

    test('should parse author', () {
      final result = PpomppuDetailParser.parse(html);
      expect(result.author, isNotEmpty);
    });

    test('should set community to ppomppu', () {
      final result = PpomppuDetailParser.parse(html);
      expect(result.community, CommunityId.ppomppu);
    });

    test('should parse date', () {
      final result = PpomppuDetailParser.parse(html);
      expect(result.date.year, 2026);
    });

    test('should extract image URLs with https prefix', () {
      final result = PpomppuDetailParser.parse(html);
      expect(result.imageUrls, isNotEmpty);
      expect(result.imageUrls.first, startsWith('https'));
    });

    test('should extract view count', () {
      final result = PpomppuDetailParser.parse(html);
      expect(result.viewCount, greaterThan(0));
    });

    test('should build content blocks from images', () {
      final result = PpomppuDetailParser.parse(html);
      expect(result.contentBlocks, isNotEmpty);
    });
  });

  group('PpomppuDetailParser comments', () {
    test('should parse total comment count', () {
      final result = PpomppuDetailParser.parse(htmlWithComments);

      expect(result.commentCount, greaterThan(0));
    });

    test('should extract comments list', () {
      final result = PpomppuDetailParser.parse(htmlWithComments);

      expect(result.comments, isNotEmpty);
    });

    test('should parse first comment author without html tags', () {
      final result = PpomppuDetailParser.parse(htmlWithComments);

      expect(result.comments.first.author, isNotEmpty);
      expect(result.comments.first.author, isNot(contains('<')));
    });

    test('should parse first comment content as plain text', () {
      final result = PpomppuDetailParser.parse(htmlWithComments);

      expect(result.comments.first.content, isNotEmpty);
      expect(result.comments.first.content, isNot(contains('<')));
    });

    test('should set comment id from comment no field', () {
      final result = PpomppuDetailParser.parse(htmlWithComments);

      expect(result.comments.first.id, greaterThan(0));
    });

    test('should parse recommend count from vote_count', () {
      final result = PpomppuDetailParser.parse(htmlWithComments);

      for (final c in result.comments) {
        expect(c.recommendCount, greaterThanOrEqualTo(0));
      }
    });

    test('should leave comments empty when post has no comments', () {
      final result = PpomppuDetailParser.parse(html);

      expect(result.comments, isEmpty);
      expect(result.commentCount, 0);
    });
  });
}
