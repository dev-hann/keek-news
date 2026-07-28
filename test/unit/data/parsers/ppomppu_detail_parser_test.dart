import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:humoruniv/data/parsers/ppomppu_detail_parser.dart';
import 'package:humoruniv/domain/entities/community.dart';

void main() {
  late String html;

  setUpAll(() {
    html = File(
      'test/fixtures/ppomppu/detail_770409.html',
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
}
