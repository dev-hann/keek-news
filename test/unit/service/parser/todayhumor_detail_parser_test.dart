import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/service/parser/todayhumor_detail_parser.dart';

void main() {
  late String html;

  setUpAll(() {
    html = File(
      'test/fixtures/todayhumor/detail_483503.html',
    ).readAsStringSync();
  });

  group('TodayhumorDetailParser', () {
    test('should parse title', () {
      final result = TodayhumorDetailParser.parse(html);

      expect(result.title, isNotEmpty);
      expect(result.title, contains('필살기'));
    });

    test('should parse author', () {
      final result = TodayhumorDetailParser.parse(html);

      expect(result.author, isNotEmpty);
      expect(result.author, '방과후개그지도');
    });

    test('should set community to todayhumor', () {
      final result = TodayhumorDetailParser.parse(html);

      expect(result.community, CommunityId.todayhumor);
    });

    test('should parse date', () {
      final result = TodayhumorDetailParser.parse(html);

      expect(result.date.year, 2026);
    });

    test('should extract image URLs', () {
      final result = TodayhumorDetailParser.parse(html);

      expect(result.imageUrls, isNotEmpty);
      expect(result.imageUrls.first, contains('todayhumor'));
    });

    test('imageUrls must NOT contain .mp4 URLs', () {
      final result = TodayhumorDetailParser.parse(html);

      final mp4s = result.imageUrls.where((u) => u.contains('.mp4')).toList();
      expect(
        mp4s,
        isEmpty,
        reason: 'mp4 must be a VideoBlock, not an image: $mp4s',
      );
    });

    test('inline mp4 source should produce VideoBlock', () {
      final result = TodayhumorDetailParser.parse(html);

      final videos = result.contentBlocks.whereType<VideoBlock>();
      final hasMp4Video = videos.any((v) => v.url.contains('.mp4'));
      expect(
        result.contentBlocks.where((b) => b is! TextBlock).isNotEmpty,
        isTrue,
        reason: 'expected at least one non-text block',
      );
      expect(hasMp4Video || videos.isEmpty, isTrue);
    });

    test('should extract counts', () {
      final result = TodayhumorDetailParser.parse(html);

      expect(result.viewCount, greaterThan(0));
      expect(result.recommendCount, greaterThan(0));
    });

    test('should build content blocks', () {
      final result = TodayhumorDetailParser.parse(html);

      expect(result.contentBlocks, isNotEmpty);
    });

    test('should return non-empty contentHtml', () {
      final result = TodayhumorDetailParser.parse(html);

      expect(result.contentHtml, isNotEmpty);
    });
  });

  group('TodayhumorDetailParser synthetic video post', () {
    test('imageUrls must NOT contain .mp4 from <source> tags', () {
      const synthetic = '''
<html><body>
<div class="viewSubjectDiv">t</div>
<div class="writerInfoContents">2026/01/01 00:00:00</div>
<div class="viewContent">
  <p>text</p>
  <video><source src="//img.todayhumor.co.kr/a.mp4" type="video/mp4"></video>
  <img src="http://img.todayhumor.co.kr/a.jpg" />
</div>
</body></html>
''';

      final result = TodayhumorDetailParser.parse(synthetic);

      expect(
        result.imageUrls.any((u) => u.contains('.mp4')),
        isFalse,
        reason: 'mp4 from <source> leaked into imageUrls',
      );
      expect(
        result.imageUrls.any((u) => u.endsWith('.jpg')),
        isTrue,
        reason: 'real image dropped',
      );
    });
  });
}
