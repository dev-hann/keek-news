import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/service/parser/ppomppu_detail_parser.dart';

void main() {
  group('PpomppuDetailParser 비디오 파싱', () {
    late String html;

    setUpAll(() {
      html = File(
        'test/fixtures/ppomppu/detail_video_770512.html',
      ).readAsStringSync();
    });

    test('비디오 URL이 imageUrls에 포함되지 않아야 함', () {
      final result = PpomppuDetailParser.parse(html);

      expect(
        result.imageUrls.any((u) => u.contains('.mp4')),
        isFalse,
        reason: 'mp4는 VideoBlock이어야 하며 imageUrls에 섞이면 깨진 이미지 발생',
      );
    });

    test('imageUrls는 로드 가능한 이미지 URL만 포함해야 함', () {
      final result = PpomppuDetailParser.parse(html);

      for (final u in result.imageUrls) {
        expect(
          u.contains('.mp4') || u.contains('.webm'),
          isFalse,
          reason: '비디오 URL이 imageUrls에 있음: $u',
        );
      }
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
