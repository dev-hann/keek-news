import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:humoruniv/data/parsers/fmkorea_list_parser.dart';
import 'package:humoruniv/data/parsers/fmkorea_detail_parser.dart';

import 'helpers.dart';

void main() {
  final skip = Platform.environment['SMOKE'] != '1';

  group('Smoke: fmkorea', () {
    test('list parser should parse live humorbest page', () async {
      final html = await fetchHtml(
        'https://www.fmkorea.com/humorbest',
        encoding: 'utf-8',
        desktop: true,
      );

      if (html.contains('보안 시스템') || html.contains('Cloudflare')) {
        return;
      }

      final posts = FmkoreaListParser.parse(html);

      expect(posts, isNotEmpty);
      expect(posts.first.title, isNotEmpty);
      expect(posts.first.id, isNotEmpty);
    }, skip: skip);

    test('detail parser should parse live post', () async {
      final listHtml = await fetchHtml(
        'https://www.fmkorea.com/humorbest',
        encoding: 'utf-8',
        desktop: true,
      );

      if (listHtml.contains('보안 시스템') || listHtml.contains('Cloudflare')) {
        return;
      }

      final posts = FmkoreaListParser.parse(listHtml);
      expect(posts, isNotEmpty);

      final detailHtml = await fetchHtml(
        'https://www.fmkorea.com/${posts.first.id}',
        encoding: 'utf-8',
        desktop: true,
      );
      final detail = FmkoreaDetailParser.parse(detailHtml);

      expect(detail.title, isNotEmpty);
    }, skip: skip);
  });
}
