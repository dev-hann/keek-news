import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:humoruniv/data/parsers/fmkorea_detail_parser.dart';
import 'package:humoruniv/domain/entities/community.dart';

void main() {
  late String html;

  setUpAll(() {
    html = File(
      'test/fixtures/fmkorea/detail_10141145310.html',
    ).readAsStringSync();
  });

  group('FmkoreaDetailParser', () {
    test('should parse title', () {
      final result = FmkoreaDetailParser.parse(html);
      expect(result.title, contains('구마모토'));
    });

    test('should parse author', () {
      final result = FmkoreaDetailParser.parse(html);
      expect(result.author, isNotEmpty);
    });

    test('should set community to fmkorea', () {
      final result = FmkoreaDetailParser.parse(html);
      expect(result.community, CommunityId.fmkorea);
    });

    test('should parse absolute date', () {
      final result = FmkoreaDetailParser.parse(html);
      expect(result.date.year, 2026);
    });

    test('should extract media from content', () {
      final result = FmkoreaDetailParser.parse(html);
      expect(result.contentBlocks, isNotEmpty);
    });

    test('should have non-empty contentHtml', () {
      final result = FmkoreaDetailParser.parse(html);
      expect(result.contentHtml, isNotEmpty);
    });
  });
}
