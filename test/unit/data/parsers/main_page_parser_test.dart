import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/data/parsers/main_page_parser.dart';

void main() {
  late String fixtureHtml;

  setUp(() {
    fixtureHtml = File('test/fixtures/main_page.html').readAsStringSync();
  });

  group('MainPageParser', () {
    test(
      'should return list of posts when html contains valid pds best section',
      () {
        final result = MainPageParser.parseBestPosts(fixtureHtml);

        expect(result, isNotEmpty);
        expect(result.first.title, isNotEmpty);
        expect(result.first.id, greaterThan(0));
        expect(result.first.recommendCount, greaterThanOrEqualTo(0));
        expect(result.first.url, contains('number='));
      },
    );

    test('should return empty list when html is empty string', () {
      final result = MainPageParser.parseBestPosts('');

      expect(result, isEmpty);
    });

    test('should return empty list when html has no pds best elements', () {
      final result = MainPageParser.parseBestPosts(
        '<html><body></body></html>',
      );

      expect(result, isEmpty);
    });

    test('should extract post id from li element id attribute', () {
      final result = MainPageParser.parseBestPosts(fixtureHtml);

      expect(result.first.id, equals(1410183));
    });

    test('should extract title from span element', () {
      final result = MainPageParser.parseBestPosts(fixtureHtml);

      expect(result.first.title, contains('과 대표가 사과문을 쓴 이유'));
    });

    test('should extract recommend count from em element', () {
      final result = MainPageParser.parseBestPosts(fixtureHtml);

      expect(result.first.recommendCount, equals(906));
    });

    test('should extract url from parent anchor href', () {
      final result = MainPageParser.parseBestPosts(fixtureHtml);

      expect(result.first.url, contains('table=pds'));
      expect(result.first.url, contains('number=1410183'));
    });

    test('should parse all best posts in fixture', () {
      final result = MainPageParser.parseBestPosts(fixtureHtml);

      expect(result.length, greaterThanOrEqualTo(10));
    });

    test('should return partial results when some elements are malformed', () {
      const partialHtml = '''
      <html><body>
      <ul>
        <a href="/rd.html?path=/m/main/pds/1&url=/board/read.html&table=pds&number=12345">
          <li id="pds_best_li_12345">
            <span id="title_chk_pds-12345">Valid Post Title</span>
            <em>100</em>
          </li>
        </a>
        <a href="/rd.html?path=/m/main/pds/2&url=/board/read.html&table=pds&number=99999">
          <li id="pds_best_li_99999">
          </li>
        </a>
      </ul>
      </body></html>
      ''';

      final result = MainPageParser.parseBestPosts(partialHtml);

      expect(result.length, equals(2));
      expect(result.first.title, equals('Valid Post Title'));
      expect(result.first.recommendCount, equals(100));
      expect(result.last.title, isEmpty);
      expect(result.last.recommendCount, equals(0));
    });
  });
}
