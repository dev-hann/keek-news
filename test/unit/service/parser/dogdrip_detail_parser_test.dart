import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/service/parser/dogdrip_detail_parser.dart';

void main() {
  group('DogdripDetailParser fixture 716024142', () {
    late String html;

    setUpAll(() {
      html = File(
        'test/fixtures/dogdrip/detail_716024142.html',
      ).readAsStringSync();
    });

    test('should parse title', () {
      final result = DogdripDetailParser.parse(html);
      expect(result.title, contains('악마의 진명'));
    });

    test('should parse author', () {
      final result = DogdripDetailParser.parse(html);
      expect(result.author, isNotEmpty);
    });

    test('should set community to dogdrip', () {
      final result = DogdripDetailParser.parse(html);
      expect(result.community, CommunityId.dogdrip);
    });

    test('should extract image URLs with full domain', () {
      final result = DogdripDetailParser.parse(html);
      expect(result.imageUrls, isNotEmpty);
      expect(result.imageUrls.first, startsWith('https'));
    });

    test('should build content blocks', () {
      final result = DogdripDetailParser.parse(html);
      expect(result.contentBlocks, isNotEmpty);
    });

    test('should have non-empty contentHtml', () {
      final result = DogdripDetailParser.parse(html);
      expect(result.contentHtml, isNotEmpty);
    });
  });

  group('DogdripDetailParser fixture 716302509 (video+image post)', () {
    late String html;

    setUpAll(() {
      html = File(
        'test/fixtures/dogdrip/detail_716302509.html',
      ).readAsStringSync();
    });

    test('imageUrls must NOT contain .mp4 URLs', () {
      final result = DogdripDetailParser.parse(html);
      final mp4s = result.imageUrls.where((u) => u.contains('.mp4')).toList();
      expect(
        mp4s,
        isEmpty,
        reason: 'mp4 must be a VideoBlock, not an image: $mp4s',
      );
    });

    test('imageUrls must NOT contain .svg URLs', () {
      final result = DogdripDetailParser.parse(html);
      final svgs = result.imageUrls.where((u) => u.endsWith('.svg')).toList();
      expect(
        svgs,
        isEmpty,
        reason: 'svg cannot be decoded by CachedNetworkImage: $svgs',
      );
    });

    test('imageUrls must NOT contain /modules/ UI chrome paths', () {
      final result = DogdripDetailParser.parse(html);
      final chrome = result.imageUrls
          .where((u) => u.contains('/modules/'))
          .toList();
      expect(
        chrome,
        isEmpty,
        reason: 'UI chrome leaked into imageUrls: $chrome',
      );
    });

    test('protocol-relative //rc.dogdrip.net must resolve to CDN host', () {
      final result = DogdripDetailParser.parse(html);
      for (final u in result.imageUrls) {
        expect(
          u.contains('dogdrip.net//rc.dogdrip.net'),
          isFalse,
          reason: 'Mangled double-host URL: $u',
        );
      }
    });

    test('contentBlocks should contain VideoBlock for inline mp4', () {
      final result = DogdripDetailParser.parse(html);
      final videos = result.contentBlocks.whereType<VideoBlock>();
      expect(
        videos,
        isNotEmpty,
        reason: 'inline <video> must yield VideoBlock',
      );
      expect(videos.first.url, contains('.mp4'));
    });

    test('real content image URL should be loadable', () {
      final result = DogdripDetailParser.parse(html);
      expect(
        result.imageUrls.any(
          (u) =>
              u.contains('647926ace8e135bbb30c1880abf15d33') &&
              u.endsWith('.jpg'),
        ),
        isTrue,
        reason: 'body image missing from imageUrls: ${result.imageUrls}',
      );
    });
  });
}
