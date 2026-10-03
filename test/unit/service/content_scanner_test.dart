import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/service/content_scanner.dart';

ImageBlock? _firstImage(Iterable<ContentBlock> blocks) {
  for (final b in blocks) {
    if (b is ImageBlock) return b;
  }
  return null;
}

void main() {
  group('ContentScanner noise filtering', () {
    test('skips 1px spacer images regardless of source path', () {
      final doc = html_parser.parse(
        '<div><img src="https://cdn.example.com/skin/t.gif" width="8" '
        'height="1px"><img src="https://cdn.example.com/real.jpg"></div>',
      );
      final result = ContentScanner.scanContent(doc.body!);

      final images = result.blocks.whereType<ImageBlock>().toList();
      expect(images, hasLength(1));
      expect(images.first.url, contains('real.jpg'));
    });

    test('skips spacer-named images without dimensions', () {
      final doc = html_parser.parse(
        '<div> '
        '<img src="https://cdn.example.com/spacer.gif" /> '
        '<img src="https://cdn.example.com/photo.webp" /> '
        '</div>',
      );
      final result = ContentScanner.scanContent(doc.body!);

      final images = result.blocks.whereType<ImageBlock>().toList();
      expect(images, hasLength(1));
      expect(images.first.url, contains('photo.webp'));
    });

    test('prefers data-src over placeholder src for lazy images', () {
      final doc = html_parser.parse(
        '<div> '
        '<img src="blank.gif" data-src="https://cdn.example.com/a.jpg"> '
        '</div>',
      );
      final result = ContentScanner.scanContent(doc.body!);

      final image = _firstImage(result.blocks);
      expect(image, isNotNull);
      expect(image!.url, 'https://cdn.example.com/a.jpg');
    });

    test('keeps plain src when no lazy attributes exist', () {
      final doc = html_parser.parse(
        '<div><img src="https://cdn.example.com/b.png"></div>',
      );
      final result = ContentScanner.scanContent(doc.body!);

      final image = _firstImage(result.blocks);
      expect(image, isNotNull);
      expect(image!.url, 'https://cdn.example.com/b.png');
    });

    test('link-dense chrome is not emitted as HtmlBlock', () {
      const html = '''
        <div><b><a href="/1">navigation menu item one</a>
        <a href="/2">navigation menu item two</a>
        <a href="/3">navigation menu item three</a></b></div>
      ''';
      final doc = html_parser.parse(html);
      final result = ContentScanner.scanContent(doc.body!);

      expect(result.blocks.whereType<HtmlBlock>(), isEmpty);
    });

    test('genuine rich mixed content still becomes HtmlBlock', () {
      const html = '''
        <div><b>본문 강조 텍스트가 충분히 길게 있는 문장입니다. '
        <a href="https://x.com">참고 링크</a> 그리고 마무리 문장.</b></div>
      ''';
      final doc = html_parser.parse(html);
      final result = ContentScanner.scanContent(doc.body!);

      expect(result.blocks.whereType<HtmlBlock>(), isNotEmpty);
    });
  });

  group('ContentScanner autolink anchors (href == text)', () {
    // humoruniv comment images are autolink `<a href=url>url</a>` markup —
    // no `<img>` at all. The anchor must still yield an image block.
    test('scanContentCompact turns image autolinks into image blocks', () {
      const url =
          'https://down.humoruniv.com/hwiparambbs/data/comment/'
          '2017/02/worldcup_15253_1487330699.96832.png';
      const html =
          '''
<div class="comment_body"><div class="comment_more">
<span class="autolink"><a href="$url" title="$url" >$url</a>
</span></div></div>
''';
      final doc = html_parser.parse(html);
      final blocks = ContentScanner.scanContentCompact(doc.body!);

      final images = blocks.whereType<ImageBlock>().toList();
      expect(images, hasLength(1));
      expect(images.first.url, url);
    });

    test('scanContent emits image block for self-text image link', () {
      const url = 'https://example.com/photo.jpg';
      final doc = html_parser.parse('<div><a href="$url">$url</a></div>');
      final result = ContentScanner.scanContent(doc.body!);

      expect(_firstImage(result.blocks)?.url, url);
    });

    test('non-media self-text link stays a plain link', () {
      const url = 'https://example.com/page';
      final doc = html_parser.parse('<div><a href="$url">$url</a></div>');
      final result = ContentScanner.scanContent(doc.body!);

      expect(result.blocks.whereType<ImageBlock>(), isEmpty);
      expect(result.blocks.whereType<HtmlBlock>(), isNotEmpty);
    });
  });

  group('ContentScanner session-token thumbs (url_enc)', () {
    // humoruniv `thumb.php?url_enc=…` URLs embed a per-session token that
    // expires after the page view; they must never become ImageBlocks
    // (dead carousel slot) nor VideoBlock posters (dead video frame).
    test('scanContent drops url_enc images and video posters', () {
      const html = '''
        <div>
          <div class="comment_img_div" onclick="comment_mp4_expand('x',
            'https://down.humoruniv.com/data/editor/a.mp4',
            '//timg.humoruniv.com/thumb.php?url_enc=TOKEN123',
            '348', '480', '', 'MP4', '', '', '');">
            <img src='//timg.humoruniv.com/thumb.php?url_enc=TOKEN123'
              class='comment_thumb_img'/>
          </div>
          <img src="https://down.humoruniv.com/data/editor/b.webp"/>
        </div>
      ''';
      final doc = html_parser.parse(html);
      final result = ContentScanner.scanContent(doc.body!);

      final images = result.blocks.whereType<ImageBlock>().toList();
      expect(images, hasLength(1));
      expect(images.first.url, contains('b.webp'));
      expect(result.imageUrls, hasLength(1));
      expect(result.imageUrls.first, contains('b.webp'));

      final videos = result.blocks.whereType<VideoBlock>().toList();
      expect(videos, hasLength(1));
      expect(videos.first.url, contains('a.mp4'));
      expect(videos.first.thumbnailUrl, isNull);
    });

    test('scanContentCompact drops url_enc images and video posters', () {
      const html = '''
        <div>
          <img src='//timg.humoruniv.com/thumb.php?url_enc=TOKEN123'/>
          <img src="https://down.humoruniv.com/data/editor/b.webp"/>
        </div>
      ''';
      final doc = html_parser.parse(html);
      final blocks = ContentScanner.scanContentCompact(doc.body!);

      final images = blocks.whereType<ImageBlock>().toList();
      expect(images, hasLength(1));
      expect(images.first.url, contains('b.webp'));
    });
  });

  group('ContentScanner doc-wide fallback excludes comment scopes', () {
    // With session cookies humoruniv re-ships comment GIFs as
    // comment_mp4_expand divs inside `li[id^="comment_li_"]`. The doc-wide
    // fallback loops exist for post-body media OUTSIDE the content element
    // (attach lists), so anything inside a comment item must be skipped —
    // otherwise a comment's 1s gif→mp4 becomes a bogus second carousel
    // page on the post card.
    test('comment_mp4_expand inside comment li is skipped', () {
      const html = '''
        <html><body>
        <div class="body_editor"><p>본문</p></div>
        <ul>
          <li id="comment_li_516726485">
            <span class="comment_body">
              <div class="comment_img_div"
                onclick="comment_mp4_expand('cf_1',
                  '//down-mp4.humoruniv.com/f4/abc123.mp4',
                  '//timg.humoruniv.com/thumb.php?url=x.gif', '320', '800',
                  '', '', '63KB', '//x.gif', '1.2MB');">
              </div>
            </span>
          </li>
        </ul>
        </body></html>
      ''';
      final doc = html_parser.parse(html);
      final contentEl = doc.querySelector('.body_editor')!;

      final result = ContentScanner.scanContentFull(doc, contentEl);

      final videos = result.blocks.whereType<VideoBlock>().toList();
      expect(videos, isEmpty);
    });

    test('download.php link inside best comment is skipped', () {
      const html = '''
        <html><body>
        <div class="body_editor"><p>본문</p></div>
        <div id="comment_best_wrap">
          <div class="best_li">
            <a href="download.php?url=https://down.humoruniv.com/data/c.png">
              <img src="https://timg.humoruniv.com/thumb.php?url=c.png"/>
            </a>
          </div>
        </div>
        </body></html>
      ''';
      final doc = html_parser.parse(html);
      final contentEl = doc.querySelector('.body_editor')!;

      final result = ContentScanner.scanContentFull(doc, contentEl);

      expect(result.blocks.whereType<ImageBlock>(), isEmpty);
      expect(result.imageUrls, isEmpty);
    });

    test('attach-list media outside comments still collected', () {
      const html = '''
        <html><body>
        <div class="body_editor"><p>본문</p></div>
        <div id="list_download">
          <div class="comment_img_div"
            onclick="comment_mp4_expand('mp4_0_1',
              '//down.humoruniv.com/hwiparambbs/data/pds/body.mp4',
              '//timg.humoruniv.com/thumb.php?url=body.mp4', '348', '348',
              '', 'MP4', '', '', '');">
          </div>
        </div>
        </body></html>
      ''';
      final doc = html_parser.parse(html);
      final contentEl = doc.querySelector('.body_editor')!;

      final result = ContentScanner.scanContentFull(doc, contentEl);

      final videos = result.blocks.whereType<VideoBlock>().toList();
      expect(videos, hasLength(1));
      expect(videos.single.url, contains('body.mp4'));
    });
  });
}
