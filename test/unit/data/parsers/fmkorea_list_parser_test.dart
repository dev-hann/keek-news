import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:humoruniv/data/parsers/fmkorea_list_parser.dart';
import 'package:humoruniv/domain/entities/community.dart';

void main() {
  late String html;

  setUpAll(() {
    html = File('test/fixtures/fmkorea/list_humorbest.html').readAsStringSync();
  });

  group('FmkoreaListParser', () {
    test('should parse posts from valid HTML', () {
      final result = FmkoreaListParser.parse(html);
      expect(result, isNotEmpty);
    });

    test('should set community to fmkorea', () {
      final result = FmkoreaListParser.parse(html);
      expect(result.first.community, CommunityId.fmkorea);
    });

    test('should extract id, title, url', () {
      final result = FmkoreaListParser.parse(html);
      final first = result.first;

      expect(first.id, isNotEmpty);
      expect(first.title, isNotEmpty);
      expect(first.url, isNotEmpty);
    });

    test('should parse recommend count', () {
      final result = FmkoreaListParser.parse(html);
      expect(result.first.recommendCount, greaterThan(0));
    });

    test('should parse relative time into DateTime', () {
      final result = FmkoreaListParser.parse(html);
      expect(result.first.publishedAt, isNotNull);
    });

    test('should return empty for empty HTML', () {
      expect(FmkoreaListParser.parse(''), isEmpty);
    });
  });
}
