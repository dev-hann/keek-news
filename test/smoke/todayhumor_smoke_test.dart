import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:humoruniv/data/parsers/todayhumor_list_parser.dart';
import 'package:humoruniv/data/parsers/todayhumor_detail_parser.dart';

import 'helpers.dart';

void main() {
  final skip = Platform.environment['SMOKE'] != '1';

  group('Smoke: todayhumor', () {
    test('list parser should parse live bestofbest page', () async {
      final html = await fetchHtml(
        'https://www.todayhumor.co.kr/board/list.php?table=bestofbest',
        encoding: 'utf-8',
      );
      final posts = TodayhumorListParser.parse(html);

      expect(posts, isNotEmpty);
      expect(posts.first.title, isNotEmpty);
      expect(posts.first.id, isNotEmpty);
      expect(posts.first.publishedAt, isNotNull);
    }, skip: skip);

    test('detail parser should parse live post page', () async {
      final listHtml = await fetchHtml(
        'https://www.todayhumor.co.kr/board/list.php?table=bestofbest',
        encoding: 'utf-8',
      );
      final posts = TodayhumorListParser.parse(listHtml);
      expect(posts, isNotEmpty);

      final detailHtml = await fetchHtml(
        'https://www.todayhumor.co.kr${posts.first.url}',
        encoding: 'utf-8',
      );
      final detail = TodayhumorDetailParser.parse(detailHtml);

      expect(detail.title, isNotEmpty);
      expect(detail.author, isNotEmpty);
    }, skip: skip);
  });
}
