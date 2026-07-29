import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/data/parsers/ppomppu_list_parser.dart';
import 'package:happy_news/domain/entities/community.dart';

void main() {
  late String html;

  setUpAll(() {
    html = File('test/fixtures/ppomppu/list_humor.html').readAsStringSync();
  });

  group('PpomppuListParser', () {
    test('should parse posts from valid HTML', () {
      final result = PpomppuListParser.parse(html);
      expect(result, isNotEmpty);
    });

    test('should set community to ppomppu', () {
      final result = PpomppuListParser.parse(html);
      expect(result.first.community, CommunityId.ppomppu);
    });

    test('should extract id, title, url', () {
      final result = PpomppuListParser.parse(html);
      final first = result.first;

      expect(first.id, isNotEmpty);
      expect(first.title, isNotEmpty);
      expect(first.url, contains('view.php'));
    });

    test('should extract author', () {
      final result = PpomppuListParser.parse(html);
      expect(result.first.author, isNotEmpty);
    });

    test('should parse date from title attribute', () {
      final result = PpomppuListParser.parse(html);
      expect(result.first.publishedAt, isNotNull);
      expect(result.first.publishedAt!.year, greaterThanOrEqualTo(2026));
    });

    test('should parse view count', () {
      final result = PpomppuListParser.parse(html);
      expect(result.first.viewCount, greaterThanOrEqualTo(0));
    });

    test('should return empty for empty HTML', () {
      expect(PpomppuListParser.parse(''), isEmpty);
    });

    test('should skip notice rows', () {
      final result = PpomppuListParser.parse(html);
      for (final item in result) {
        expect(item.id, isNot(''));
      }
    });
  });
}
