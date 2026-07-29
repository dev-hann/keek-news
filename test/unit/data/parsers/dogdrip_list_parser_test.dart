import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/data/parsers/dogdrip_list_parser.dart';
import 'package:happy_news/domain/entities/community.dart';

void main() {
  late String html;

  setUpAll(() {
    html = File('test/fixtures/dogdrip/list_dogdrip.html').readAsStringSync();
  });

  group('DogdripListParser', () {
    test('should parse posts from valid HTML', () {
      final result = DogdripListParser.parse(html);
      expect(result, isNotEmpty);
    });

    test('should set community to dogdrip', () {
      final result = DogdripListParser.parse(html);
      expect(result.first.community, CommunityId.dogdrip);
    });

    test('should extract id, title, url', () {
      final result = DogdripListParser.parse(html);
      final first = result.first;

      expect(first.id, isNotEmpty);
      expect(first.title, isNotEmpty);
      expect(first.url, isNotEmpty);
    });

    test('should parse author', () {
      final result = DogdripListParser.parse(html);
      expect(result.first.author, isNotEmpty);
    });

    test('should parse relative time into DateTime', () {
      final result = DogdripListParser.parse(html);
      expect(result.first.publishedAt, isNotNull);
    });

    test('should return empty for empty HTML', () {
      expect(DogdripListParser.parse(''), isEmpty);
    });
  });
}
