import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:humoruniv/data/parsers/todayhumor_detail_parser.dart';
import 'package:humoruniv/domain/entities/community.dart';

void main() {
  late String html;

  setUpAll(() {
    html = File(
      'test/fixtures/todayhumor/detail_483503.html',
    ).readAsStringSync();
  });

  group('TodayhumorDetailParser', () {
    test('should parse title', () {
      final result = TodayhumorDetailParser.parse(html);

      expect(result.title, isNotEmpty);
      expect(result.title, contains('필살기'));
    });

    test('should parse author', () {
      final result = TodayhumorDetailParser.parse(html);

      expect(result.author, isNotEmpty);
      expect(result.author, '방과후개그지도');
    });

    test('should set community to todayhumor', () {
      final result = TodayhumorDetailParser.parse(html);

      expect(result.community, CommunityId.todayhumor);
    });

    test('should parse date', () {
      final result = TodayhumorDetailParser.parse(html);

      expect(result.date.year, 2026);
    });

    test('should extract image URLs', () {
      final result = TodayhumorDetailParser.parse(html);

      expect(result.imageUrls, isNotEmpty);
      expect(result.imageUrls.first, contains('todayhumor'));
    });

    test('should extract counts', () {
      final result = TodayhumorDetailParser.parse(html);

      expect(result.viewCount, greaterThan(0));
      expect(result.recommendCount, greaterThan(0));
    });

    test('should build content blocks', () {
      final result = TodayhumorDetailParser.parse(html);

      expect(result.contentBlocks, isNotEmpty);
    });

    test('should return non-empty contentHtml', () {
      final result = TodayhumorDetailParser.parse(html);

      expect(result.contentHtml, isNotEmpty);
    });
  });
}
