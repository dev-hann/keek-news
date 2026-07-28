import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:humoruniv/data/parsers/ppomppu_list_parser.dart';
import 'package:humoruniv/data/parsers/ppomppu_detail_parser.dart';

import 'helpers.dart';

void main() {
  final skip = Platform.environment['SMOKE'] != '1';

  group('Smoke: ppomppu', () {
    test('list parser should parse live humor board', () async {
      final html = await fetchHtml(
        'https://www.ppomppu.co.kr/zboard/zboard.php?id=humor',
        encoding: 'cp949',
      );
      final posts = PpomppuListParser.parse(html);

      expect(posts, isNotEmpty);
      expect(posts.first.title, isNotEmpty);
      expect(posts.first.id, isNotEmpty);
    }, skip: skip);

    test('detail parser should parse live post', () async {
      final listHtml = await fetchHtml(
        'https://www.ppomppu.co.kr/zboard/zboard.php?id=humor',
        encoding: 'cp949',
      );
      final posts = PpomppuListParser.parse(listHtml);
      expect(posts, isNotEmpty);

      final detailUrl =
          'https://www.ppomppu.co.kr/zboard/${posts.first.url}';
      final detailHtml = await fetchHtml(detailUrl, encoding: 'cp949');
      final detail = PpomppuDetailParser.parse(detailHtml);

      expect(detail.title, isNotEmpty);
      expect(detail.imageUrls, isNotEmpty);
    }, skip: skip);
  });
}
