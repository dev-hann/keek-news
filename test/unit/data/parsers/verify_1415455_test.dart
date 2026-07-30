import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/data/parsers/content_scanner.dart';
import 'package:happy_news/data/parsers/post_detail_parser.dart';
import 'package:happy_news/domain/entities/content_block.dart';
import 'package:html/parser.dart' as html_parser;

void main() {
  test('verify post 1415455: video extraction from real HTML', () {
    final html = File('test/fixtures/pds_1415455.html').readAsStringSync();
    final doc = html_parser.parse(html);
    final bodyEditor = doc.querySelector('.body_editor');
    print('body_editor found: ${bodyEditor != null}');

    final mp4Divs = doc.querySelectorAll('[onclick*="comment_mp4_expand"]');
    print('mp4_expand elements: ${mp4Divs.length}');
    for (var i = 0; i < mp4Divs.length; i++) {
      final inBody = bodyEditor?.contains(mp4Divs[i]) ?? false;
      print('  [$i] inBodyEditor=$inBody');
    }

    final result = ContentScanner.scanFull(doc, bodyEditor ?? doc.body!);
    print('blocks: ${result.blocks.length}');
    for (final b in result.blocks) {
      if (b is VideoBlock) {
        print('  Video: ${b.url}');
      } else if (b is ImageBlock)
        print('  Image: ${b.url}');
      else if (b is TextBlock) {
        final t = b.text.substring(0, b.text.length > 40 ? 40 : b.text.length);
        print('  Text: $t');
      }
    }

    final videos = result.blocks.whereType<VideoBlock>().toList();
    print('VideoBlocks: ${videos.length}');
    expect(videos, isNotEmpty, reason: 'Post 1415455 should have VideoBlocks');
    expect(videos.first.url, contains('.mp4'));
  });

  test(
    'verify post 1415455: mp4 best comment has clean content and single video',
    () {
      final html = File('test/fixtures/pds_1415455.html').readAsStringSync();
      final detail = PostDetailParser.parse(html);

      final mp4Comment = detail.comments.firstWhere(
        (c) => c.content.contains('똥이나 처먹어'),
        orElse: () => throw StateError('mp4 best comment not found'),
      );

      expect(mp4Comment.content, contains('똥이나 처먹어'));
      const leaked = ['MP4', '0.4MB', '이동', '추천', '답글', '원본', '추천완료'];
      for (final token in leaked) {
        expect(
          mp4Comment.content,
          isNot(contains(token)),
          reason: 'content should not leak UI token "$token"',
        );
      }

      expect(
        mp4Comment.mediaBlocks.whereType<VideoBlock>(),
        hasLength(1),
        reason: 'mp4 comment should yield exactly one VideoBlock',
      );
      expect(
        mp4Comment.mediaBlocks.whereType<ImageBlock>(),
        isEmpty,
        reason: 'poster must not be emitted as a separate ImageBlock',
      );
    },
  );
}
