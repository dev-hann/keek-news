import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:humoruniv/data/parsers/ppomppu_detail_parser.dart';
import 'package:humoruniv/domain/entities/content_block.dart';

void main() {
  group('PpomppuDetailParser 비디오 파싱', () {
    late String html;

    setUpAll(() {
      html = File(
        'test/fixtures/ppomppu/detail_video_770512.html',
      ).readAsStringSync();
    });

    test('비디오 URL이 imageUrls에 포함되어야 함', () {
      final result = PpomppuDetailParser.parse(html);

      expect(
        result.imageUrls.any((u) => u.contains('.mp4')),
        isTrue,
        reason: 'mp4 비디오 URL이 추출되어야 함',
      );
    });

    test('contentBlocks에 VideoBlock이 있어야 함', () {
      final result = PpomppuDetailParser.parse(html);

      final videoBlocks = result.contentBlocks.whereType<VideoBlock>();
      expect(videoBlocks, isNotEmpty, reason: 'VideoBlock이 생성되어야 함');
      expect(videoBlocks.first.url, contains('.mp4'));
    });

    test('"browser does not support" 텍스트가 TextBlock으로 들어가면 안 됨', () {
      final result = PpomppuDetailParser.parse(html);

      final textBlocks = result.contentBlocks.whereType<TextBlock>();
      for (final tb in textBlocks) {
        expect(
          tb.text.contains('browser does not support'),
          isFalse,
          reason: '비디오 fallback 텍스트가 노출되면 안 됨',
        );
      }
    });
  });
}
