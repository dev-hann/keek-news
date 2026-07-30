import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/service/parser/ppomppu_list_parser.dart';

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

    test('should parse comment count from baseList-c span', () {
      final result = PpomppuListParser.parse(html);
      final post = result.firstWhere((p) => p.id == '770403');

      expect(post.commentCount, 4);
    });

    test('should parse comment count as integer for every row', () {
      final result = PpomppuListParser.parse(html);

      for (final item in result) {
        expect(item.commentCount, greaterThanOrEqualTo(0));
      }
    });

    test('should parse comment count zero when span absent', () {
      const snippet = '''
      <table><tr class="baseList">
        <td class="baseList-numb">123</td>
        <td><a class="baseList-title" href="view.php?id=humor&no=999"><span>t</span></a></td>
        <td class="baseList-time">12:00</td>
        <td title="26.07.30 12:00:00"></td>
      </tr></table>
      ''';

      final result = PpomppuListParser.parse(snippet);

      expect(result.single.commentCount, 0);
    });
  });
}
