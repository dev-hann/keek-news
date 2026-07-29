import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/data/parsers/board_list_parser.dart';

import 'helpers.dart';

void main() {
  final skip = Platform.environment['SMOKE'] != '1';

  group('Smoke: board list parser with live server', () {
    test('should fetch and parse board list from humoruniv.com', () async {
      final html = await fetchHtml('/board/list.html?table=pds&pg=0');
      final result = BoardListParser.parse(html);

      expect(
        result.posts,
        isNotEmpty,
        reason: 'Board posts should not be empty',
      );

      for (final post in result.posts) {
        expect(post.id, greaterThan(0));
        expect(post.title, isNotEmpty);
        expect(post.url, contains('table='));
      }
    }, skip: skip);

    test('should extract pagination info from board list', () async {
      final html = await fetchHtml('/board/list.html?table=pds&pg=0');
      final result = BoardListParser.parse(html);

      expect(result.currentPage, greaterThanOrEqualTo(0));
      expect(result.totalPage, greaterThanOrEqualTo(1));
    }, skip: skip);

    test('should parse board list with sort parameter', () async {
      final html = await fetchHtml('/board/list.html?table=pds&pg=0&sort=day');
      final result = BoardListParser.parse(html);

      expect(
        result.posts,
        isNotEmpty,
        reason: 'Sorted board posts should not be empty',
      );
    }, skip: skip);
  });
}
