import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/service/parser/post_detail_parser.dart';

import 'helpers.dart';

void main() {
  final skip = Platform.environment['SMOKE'] != '1';

  group('Smoke: post detail parser with live humoruniv post 1419432', () {
    test('should parse title, author, counts and body content', () async {
      final html = await fetchHtml('/board/read.html?table=pds&number=1419432');
      final detail = PostDetailParser.parse(html);

      print('--- title: ${detail.title}');
      print('--- author: ${detail.author}');
      print('--- date: ${detail.date}');
      print('--- recommend: ${detail.recommendCount}');
      print('--- notRecommend: ${detail.notRecommendCount}');
      print('--- view: ${detail.viewCount}');
      print('--- commentCount: ${detail.commentCount}');
      print('--- imageUrls: ${detail.imageUrls}');
      print('--- contentBlocks count: ${detail.contentBlocks.length}');
      for (var i = 0; i < detail.contentBlocks.length; i++) {
        final b = detail.contentBlocks[i];
        final desc = switch (b) {
          TextBlock(:final text) =>
            'TextBlock(${text.length} chars: "${text.length > 40 ? '${text.substring(0, 40)}...' : text}")',
          ImageBlock(:final url, :final thumbnailUrl) =>
            'ImageBlock(url=$url, thumb=$thumbnailUrl)',
          VideoBlock(:final url) => 'VideoBlock($url)',
          HtmlBlock(:final html) => 'HtmlBlock(${html.length} chars)',
        };
        print('  block[$i]: $desc');
      }
      print('--- comments count: ${detail.comments.length}');

      expect(detail.title, isNotEmpty);
      expect(detail.author, isNotEmpty);
      expect(detail.imageUrls, isNotEmpty, reason: 'body_editor 이미지가 추출되어야 함');
      expect(detail.contentBlocks, isNotEmpty, reason: '본문 블록이 최소 1개 있어야 함');
      expect(
        detail.contentBlocks.any((b) => b is ImageBlock),
        isTrue,
        reason: 'ImageBlock이 최소 1개 있어야 함',
      );
      expect(
        detail.viewCount,
        greaterThan(1000),
        reason: '조회수가 작성일 연도(2026)가 아닌 실제 조회수여야 함',
      );
    }, skip: skip);
  });
}
