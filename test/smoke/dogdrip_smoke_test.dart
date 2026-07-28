import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:humoruniv/data/parsers/dogdrip_list_parser.dart';
import 'package:humoruniv/data/parsers/dogdrip_detail_parser.dart';

import 'helpers.dart';

void main() {
  final skip = Platform.environment['SMOKE'] != '1';

  group('Smoke: dogdrip', () {
    test('list parser should parse live dogdrip board', () async {
      final html = await fetchHtml(
        'https://www.dogdrip.net/index.php?mid=dogdrip',
        encoding: 'utf-8',
      );
      final posts = DogdripListParser.parse(html);

      expect(posts, isNotEmpty);
      expect(posts.first.title, isNotEmpty);
      expect(posts.first.id, isNotEmpty);
    }, skip: skip);

    test('detail parser should parse live post', () async {
      final listHtml = await fetchHtml(
        'https://www.dogdrip.net/index.php?mid=dogdrip',
        encoding: 'utf-8',
      );
      final posts = DogdripListParser.parse(listHtml);
      expect(posts, isNotEmpty);

      final detailHtml = await fetchHtml(
        'https://www.dogdrip.net/${posts.first.id}',
        encoding: 'utf-8',
      );
      final detail = DogdripDetailParser.parse(detailHtml);

      expect(detail.title, isNotEmpty);
    }, skip: skip);
  });
}
