import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/data/parsers/content_scanner.dart';
import 'package:happy_news/domain/entities/content_block.dart';
import 'package:html/parser.dart' as html_parser;

void main() {
  ContentScanResult scan(String innerHtml, {String? outsideBody}) {
    final doc = html_parser.parse(
      '<html><body>'
      '${outsideBody ?? ''}'
      '<div id="body_editor">$innerHtml</div>'
      '</body></html>',
    );
    return ContentScanner.scanFull(doc, doc.querySelector('#body_editor')!);
  }

  group('comment_mp4_expand video extraction', () {
    test('should extract VideoBlock from OnClick inside body_editor', () {
      final result = scan(
        '<div onclick="javascript:comment_mp4_expand(\'cf123\', \'//down-mp4.humoruniv.com/c9/test.mp4\', \'//timg.humoruniv.com/thumb.php?url=t.jpg\', \'300\')">'
        'thumb</div>',
      );
      final videos = result.blocks.whereType<VideoBlock>().toList();
      expect(videos, hasLength(1));
      expect(videos.first.url, contains('.mp4'));
    });

    test(
      'should extract VideoBlock from OUTSIDE body_editor (whole-doc scan)',
      () {
        final result = scan(
          '<div>just text here</div>',
          outsideBody:
              '<div onclick="javascript:comment_mp4_expand(\'mp4_0_1\', \'//down.humoruniv.com/data/pds/video.mp4\', \'//timg.humoruniv.com/thumb.jpg\', \'348\')">'
              '<img src="//timg.humoruniv.com/thumb.jpg" /></div>',
        );
        final videos = result.blocks.whereType<VideoBlock>().toList();
        expect(videos, hasLength(1));
        expect(
          videos.first.url,
          'https://down.humoruniv.com/data/pds/video.mp4',
        );
      },
    );

    test('should not produce VideoBlock without comment_mp4_expand', () {
      final result = scan('<div onclick="javascript:other_fn()">text</div>');
      expect(result.blocks.whereType<VideoBlock>(), isEmpty);
    });

    test('should dedup same video inside and outside body_editor', () {
      final result = scan(
        '<div onclick="javascript:comment_mp4_expand(\'a\', \'//down.humoruniv.com/v.mp4\', \'//t.humoruniv.com/t.jpg\', \'1\')">in body</div>',
        outsideBody:
            '<div onclick="javascript:comment_mp4_expand(\'b\', \'//down.humoruniv.com/v.mp4\', \'//t.humoruniv.com/t.jpg\', \'1\')">outside</div>',
      );
      expect(result.blocks.whereType<VideoBlock>(), hasLength(1));
    });
  });
}
