import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:humoruniv/data/parsers/dogdrip_detail_parser.dart';
import 'package:humoruniv/domain/entities/community.dart';

void main() {
  late String html;

  setUpAll(() {
    html = File(
      'test/fixtures/dogdrip/detail_716024142.html',
    ).readAsStringSync();
  });

  group('DogdripDetailParser', () {
    test('should parse title', () {
      final result = DogdripDetailParser.parse(html);
      expect(result.title, contains('악마의 진명'));
    });

    test('should parse author', () {
      final result = DogdripDetailParser.parse(html);
      expect(result.author, isNotEmpty);
    });

    test('should set community to dogdrip', () {
      final result = DogdripDetailParser.parse(html);
      expect(result.community, CommunityId.dogdrip);
    });

    test('should extract image URLs with full domain', () {
      final result = DogdripDetailParser.parse(html);
      expect(result.imageUrls, isNotEmpty);
      expect(result.imageUrls.first, startsWith('https'));
    });

    test('should build content blocks', () {
      final result = DogdripDetailParser.parse(html);
      expect(result.contentBlocks, isNotEmpty);
    });

    test('should have non-empty contentHtml', () {
      final result = DogdripDetailParser.parse(html);
      expect(result.contentHtml, isNotEmpty);
    });
  });
}
