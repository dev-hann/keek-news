import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/service/dio_html_service.dart';

void main() {
  late DioHtmlService client;
  setUp(() {
    client = DioHtmlService(dio: Dio(BaseOptions()), encoding: 'utf-8');
  });
  group('DioHtmlService scan methods', () {
    group('scan', () {
      test('should extract text as TextBlock', () {
        final doc = html_parser.parse(
          '<div class="body_editor">Hello world</div>',
        );
        final container = doc.querySelector('.body_editor')!;

        final result = client.scanContent(container);

        expect(result.blocks, hasLength(1));
        expect(result.blocks.first, isA<TextBlock>());
        expect((result.blocks.first as TextBlock).text, 'Hello world');
      });

      test('should extract image from img tag', () {
        final doc = html_parser.parse('''
          <div class="body_editor">
            <div class="simple_attach_img_div">
              <img src="http://example.com/img.jpg" img_file_url="http://example.com/img.jpg" class="img_compress" />
            </div>
          </div>
        ''');
        final container = doc.querySelector('.body_editor')!;

        final result = client.scanContent(container);

        expect(result.blocks.any((b) => b is ImageBlock), isTrue);
        expect(result.imageUrls, contains('http://example.com/img.jpg'));
      });

      test('should extract image with thumbnail', () {
        final doc = html_parser.parse('''
          <div class="body_editor">
            <img src="http://example.com/thumb.jpg" img_file_url="http://example.com/full.jpg" class="img_compress" />
          </div>
        ''');
        final container = doc.querySelector('.body_editor')!;

        final result = client.scanContent(container);

        final img = result.blocks.whereType<ImageBlock>().first;
        expect(img.url, 'http://example.com/full.jpg');
        expect(img.thumbnailUrl, 'http://example.com/thumb.jpg');
      });

      test('should preserve order of text and images', () {
        final doc = html_parser.parse('''
          <div class="body_editor">
            Text before
            <img src="http://example.com/img.jpg" img_file_url="http://example.com/img.jpg" class="img_compress" />
            Text after
          </div>
        ''');
        final container = doc.querySelector('.body_editor')!;

        final result = client.scanContent(container);

        final types = result.blocks.map((b) => b.runtimeType).toList();
        expect(types, contains(TextBlock));
        expect(types, contains(ImageBlock));

        final textBeforeIdx = result.blocks.indexWhere(
          (b) => b is TextBlock && b.text.contains('Text before'),
        );
        final imgIdx = result.blocks.indexWhere((b) => b is ImageBlock);
        final textAfterIdx = result.blocks.indexWhere(
          (b) => b is TextBlock && b.text.contains('Text after'),
        );

        expect(textBeforeIdx, lessThan(imgIdx));
        expect(imgIdx, lessThan(textAfterIdx));
      });

      test('should skip noise elements', () {
        final doc = html_parser.parse('''
          <div class="body_editor">
            <div class="comment_thumb_notice">some notice</div>
            <div class="comment_crop_href">crop link</div>
            <div class="comment_crop_href_mp4">mp4 crop</div>
            <iframe src="http://example.com"></iframe>
            <p>Actual content</p>
          </div>
        ''');
        final container = doc.querySelector('.body_editor')!;

        final result = client.scanContent(container);

        final texts = result.blocks
            .whereType<TextBlock>()
            .map((b) => b.text)
            .toList();
        expect(texts, isNot(contains('some notice')));
        expect(texts, isNot(contains('crop link')));
        expect(texts, isNot(contains('mp4 crop')));
        expect(texts, contains('Actual content'));
      });

      test('should skip images with /images/ path', () {
        final doc = html_parser.parse('''
          <div class="body_editor">
            <img src="/images/spacer.gif" />
          </div>
        ''');
        final container = doc.querySelector('.body_editor')!;

        final result = client.scanContent(container);

        expect(result.blocks.whereType<ImageBlock>(), isEmpty);
      });

      test('should detect video element as VideoBlock', () {
        final doc = html_parser.parse('''
          <div class="body_editor">
            <div>
              <video width="480" height="360" poster="http://example.com/thumb.jpg" controls>
                <source src="http://example.com/video.mp4" type="video/mp4">
              </video>
            </div>
          </div>
        ''');
        final container = doc.querySelector('.body_editor')!;

        final result = client.scanContent(container);

        expect(result.blocks.any((b) => b is VideoBlock), isTrue);
        final video = result.blocks.whereType<VideoBlock>().first;
        expect(video.url, 'http://example.com/video.mp4');
        expect(video.thumbnailUrl, 'http://example.com/thumb.jpg');
        expect(video.width, 480);
        expect(video.height, 360);
      });

      test('should extract YouTube link as VideoBlock', () {
        final doc = html_parser.parse('''
          <div class="body_editor">
            <span class="autolink"><a href="https://www.youtube.com/watch?v=dQw4w9WgXcQ">youtube link</a></span>
          </div>
        ''');
        final container = doc.querySelector('.body_editor')!;

        final result = client.scanContent(container);

        expect(result.blocks.any((b) => b is VideoBlock), isTrue);
        final video = result.blocks.whereType<VideoBlock>().first;
        expect(video.url, contains('youtube.com'));
        expect(video.thumbnailUrl, contains('img.youtube.com'));
      });

      test('should extract link as HtmlBlock', () {
        final doc = html_parser.parse('''
          <div class="body_editor">
            <span class="autolink"><a href="https://example.com/page">visit page</a></span>
          </div>
        ''');
        final container = doc.querySelector('.body_editor')!;

        final result = client.scanContent(container);

        expect(result.blocks.any((b) => b is HtmlBlock), isTrue);
        final html = result.blocks.whereType<HtmlBlock>().first;
        expect(html.html, contains('href="https://example.com/page"'));
        expect(html.html, contains('visit page'));
      });

      test('should deduplicate URLs', () {
        final doc = html_parser.parse('''
          <div class="body_editor">
            <div class="simple_attach_img_div">
              <img src="http://example.com/img.jpg" img_file_url="http://example.com/img.jpg" class="img_compress" />
            </div>
            <div class="comment_img_div">
              <img src="http://example.com/img.jpg" img_file_url="http://example.com/img.jpg" class="img_compress" />
            </div>
          </div>
        ''');
        final container = doc.querySelector('.body_editor')!;

        final result = client.scanContent(container);

        expect(result.blocks.whereType<ImageBlock>(), hasLength(1));
      });

      test('should normalize // URLs to https://', () {
        final doc = html_parser.parse('''
          <div class="body_editor">
            <img src="//timg.humoruniv.com/thumb.jpg" img_file_url="//timg.humoruniv.com/full.jpg" class="img_compress" />
          </div>
        ''');
        final container = doc.querySelector('.body_editor')!;

        final result = client.scanContent(container);

        final img = result.blocks.whereType<ImageBlock>().first;
        expect(img.url, startsWith('https://'));
        expect(img.thumbnailUrl, startsWith('https://'));
      });

      test('should handle empty container', () {
        final doc = html_parser.parse('<div class="body_editor"></div>');
        final container = doc.querySelector('.body_editor')!;

        final result = client.scanContent(container);

        expect(result.blocks, isEmpty);
        expect(result.imageUrls, isEmpty);
      });

      // Regression: humoruniv pds post 1419653 wraps GIF attachments as
      // <div class='comment_img_div'><a href='javascript:comment_thumb_expand'>
      //   <img class='comment_thumb_img' .../>
      //   <div class='comment_thumb_notice'>GIF</div>
      // </a></div>
      // The notice badge text ("GIF") must NOT leak as a TextBlock, because
      // the wrapper <a> is incorrectly treated as a simple-text element.
      test(
        'should not emit GIF/MP4 notice badge text from attachment wrapper',
        () {
          final doc = html_parser.parse('''
            <div class="body_editor">
              <div class="simple_attach_img_div">
                <div class="comment_img_div">
                  <a href="javascript:comment_thumb_expand('id', 'https://down.humoruniv.com/data/editor/a.gif', '//timg.humoruniv.com/thumb.php?url=https://down.humoruniv.com/data/editor/a.gif?SIZE=320x240', '320', '320', '', 'GIF', '');">
                    <img src="//timg.humoruniv.com/thumb.php?url=https://down.humoruniv.com/data/editor/a.gif?SIZE=320x240" class="comment_thumb_img" OnClick=""/>
                    <div class="comment_thumb_notice">GIF</div>
                  </a>
                  <div style="position:absolute;top:12px;left:12px;"><img src="/images/play_trans.png?tmp=3" width="40" height="40"/></div>
                </div>
              </div>
              <div class="simple_attach_img_div">
                <div class="comment_img_div pointer" OnClick="javascript:comment_mp4_expand('mp4_1_', 'https://down.humoruniv.com/data/editor/v.mp4', '//timg.humoruniv.com/thumb.php?url_enc=abc', '320', '320', '', 'MP4', '', '', '');">
                  <img src="//timg.humoruniv.com/thumb.php?url_enc=abc" class="comment_thumb_img"/>
                  <div class="comment_thumb_notice">MP4</div>
                  <div style="position:absolute;top:12px;left:12px;"><img src="/images/play_trans.png?tmp=3" width="40" height="40"/></div>
                </div>
              </div>
            </div>
          ''');
          final container = doc.querySelector('.body_editor')!;

          final result = client.scanContent(container);

          final leakedNotices = result.blocks
              .whereType<TextBlock>()
              .map((b) => b.text)
              .where((t) => t == 'GIF' || t == 'MP4')
              .toList();
          expect(
            leakedNotices,
            isEmpty,
            reason: 'GIF/MP4 attachment badges must not appear as body text',
          );
        },
      );
    });

    group('scanCompact', () {
      test('should extract images from comment body', () {
        final doc = html_parser.parse('''
          <div class="comment_body">
            <span class="comment_text">댓글 내용</span>
            <div class="comment_img_div">
              <img src="http://example.com/comment_img.jpg" img_file_url="http://example.com/comment_img.jpg" class="img_compress" />
            </div>
          </div>
        ''');
        final container = doc.querySelector('.comment_body')!;

        final result = client.scanContentCompact(container);

        expect(result, hasLength(1));
        expect(result.first, isA<ImageBlock>());
      });

      test('should extract video from onclick attribute', () {
        final doc = html_parser.parse('''
          <div class="comment_body">
            <span class="comment_text">댓글</span>
            <div OnClick="comment_mp4_expand('123','http://example.com/video.mp4','http://example.com/thumb.jpg')">
              <img src="http://example.com/thumb.jpg" />
            </div>
          </div>
        ''');
        final container = doc.querySelector('.comment_body')!;

        final result = client.scanContentCompact(container);

        expect(result.any((b) => b is VideoBlock), isTrue);
        final video = result.whereType<VideoBlock>().first;
        expect(video.url, 'http://example.com/video.mp4');
      });

      test(
        'should emit single VideoBlock for comment_mp4_expand container, '
        'dropping url_enc thumbnail (server returns 403) and no ImageBlock',
        () {
          final doc = html_parser.parse('''
            <div class="comment_body">
              <div class='comment_file'>
                <div class='comment_img_div pointer' style='width:320px;'
                    OnClick="javascript:comment_mp4_expand('mp4_714827364_3530_', 'http://down.humoruniv.com/data/comment/video.mp4', 'http://timg.humoruniv.com/thumb.php?url_enc=abc', '320', '320', '', 'MP4', '0.4MB', '', '');">
                  <img src='http://timg.humoruniv.com/thumb.php?url_enc=abc' width='320' class='comment_thumb_img' style='min-height:80px;'/>
                  <div class='comment_thumb_notice'>MP4,&nbsp; 0.4MB</div>
                  <div style='position:absolute;top:12px;left:12px;'><img src='/images/play_trans.png?tmp=3' width='40' height='40'></div>
                </div>
              </div>
              <span class="comment_text">똥이나 처먹어!</span>
            </div>
          ''');
          final container = doc.querySelector('.comment_body')!;

          final result = client.scanContentCompact(container);

          expect(result, hasLength(1));
          expect(result.whereType<ImageBlock>(), isEmpty);
          final video = result.whereType<VideoBlock>().single;
          expect(video.url, 'http://down.humoruniv.com/data/comment/video.mp4');
          expect(
            video.thumbnailUrl,
            isNull,
            reason:
                'url_enc thumbnails return 403 for any client; '
                'must be null so the UI can fall back to local '
                'frame extraction',
          );
        },
      );

      test('comment_mp4_expand keeps plaintext thumb.php thumbnail', () {
        final doc = html_parser.parse('''
            <div class="comment_body">
              <div class='comment_file'>
                <div class='comment_img_div pointer' style='width:320px;'
                    OnClick="javascript:comment_mp4_expand('mp4_1_', 'http://down.humoruniv.com/data/comment/video.mp4', 'http://timg.humoruniv.com/thumb.php?url=http://down.humoruniv.com/data/comment/v.jpg', '320', '320', '', 'MP4', '', '', '');">
                  <img src='http://timg.humoruniv.com/thumb.php?url=http://down.humoruniv.com/data/comment/v.jpg' width='320' class='comment_thumb_img'/>
                </div>
              </div>
            </div>
          ''');
        final container = doc.querySelector('.comment_body')!;

        final result = client.scanContentCompact(container);
        final video = result.whereType<VideoBlock>().single;
        expect(
          video.thumbnailUrl,
          'http://timg.humoruniv.com/thumb.php?url=http://down.humoruniv.com/data/comment/v.jpg',
          reason: 'plaintext thumb.php URLs are loadable (server renders PNG)',
        );
      });

      test('should return empty list for text-only comment', () {
        final doc = html_parser.parse('''
          <div class="comment_body">
            <span class="comment_text">그냥 텍스트 댓글</span>
          </div>
        ''');
        final container = doc.querySelector('.comment_body')!;

        final result = client.scanContentCompact(container);

        expect(result, isEmpty);
      });
    });

    group('scanFull', () {
      test('should scan content container and find inline images', () {
        final doc = html_parser.parse('''
          <html><body>
          <div class="body_editor">
            <img src="http://example.com/img.jpg" img_file_url="http://example.com/img.jpg" class="img_compress" />
          </div>
          </body></html>
        ''');
        final container = doc.querySelector('.body_editor')!;

        final result = client.scanContentFull(doc, container);

        expect(result.blocks.any((b) => b is ImageBlock), isTrue);
      });

      test('should find download links outside content container', () {
        final doc = html_parser.parse('''
          <html><body>
          <div class="body_editor">
            <p>Some text</p>
          </div>
          <div class="download_area">
            <a href="http://down.humoruniv.com/download.php?url=http://example.com/extra.jpg">
              <img src="http://example.com/extra_thumb.jpg" />
            </a>
          </div>
          </body></html>
        ''');
        final container = doc.querySelector('.body_editor')!;

        final result = client.scanContentFull(doc, container);

        final imgs = result.blocks.whereType<ImageBlock>().toList();
        expect(imgs, hasLength(1));
        expect(imgs.first.url, 'http://example.com/extra.jpg');
      });

      test('should find download video outside content container', () {
        final doc = html_parser.parse('''
          <html><body>
          <div class="body_editor">
            <p>Some text</p>
          </div>
          <div class="download_area">
            <a href="http://down.humoruniv.com/download.php?url=http://example.com/clip.mp4">
              <img src="http://example.com/clip_thumb.jpg" />
            </a>
          </div>
          </body></html>
        ''');
        final container = doc.querySelector('.body_editor')!;

        final result = client.scanContentFull(doc, container);

        expect(result.blocks.any((b) => b is VideoBlock), isTrue);
        final video = result.blocks.whereType<VideoBlock>().first;
        expect(video.url, 'http://example.com/clip.mp4');
      });

      test(
        'should not duplicate image found both inside and outside container',
        () {
          final doc = html_parser.parse('''
          <html><body>
          <div class="body_editor">
            <div class="simple_attach_img_div">
              <img src="http://timg.humoruniv.com/editor/img001.jpg"
                   img_file_url="http://timg.humoruniv.com/editor/img001.jpg"
                   class="img_compress" />
            </div>
          </div>
          <div class="download_area">
            <a href="http://down.humoruniv.com/download.php?url=http://down.humoruniv.com/editor/img001.jpg">
              <img src="http://down.humoruniv.com/editor/img001.jpg" />
            </a>
          </div>
          </body></html>
        ''');
          final container = doc.querySelector('.body_editor')!;

          final result = client.scanContentFull(doc, container);

          final imgs = result.blocks.whereType<ImageBlock>().toList();
          expect(imgs, hasLength(1));
        },
      );

      test('should not duplicate when scheme differs (http vs https)', () {
        final doc = html_parser.parse('''
          <html><body>
          <div class="body_editor">
            <img src="http://timg.humoruniv.com/editor/photo.jpg"
                 img_file_url="http://timg.humoruniv.com/editor/photo.jpg"
                 class="img_compress" />
          </div>
          <div class="download_area">
            <a href="https://down.humoruniv.com/download.php?url=https://down.humoruniv.com/editor/photo.jpg">
              <img src="https://down.humoruniv.com/editor/photo.jpg" />
            </a>
          </div>
          </body></html>
        ''');
        final container = doc.querySelector('.body_editor')!;

        final result = client.scanContentFull(doc, container);

        final imgs = result.blocks.whereType<ImageBlock>().toList();
        expect(imgs, hasLength(1));
      });

      test('should not duplicate when domain differs but path is same', () {
        final doc = html_parser.parse('''
          <html><body>
          <div class="body_editor">
            <img src="http://timg.humoruniv.com/hwiparambbs/data/editor/2505/test.jpg"
                 img_file_url="http://timg.humoruniv.com/hwiparambbs/data/editor/2505/test.jpg"
                 class="img_compress" />
          </div>
          <div class="download_area">
            <a href="download.php?url=http://down.humoruniv.com/hwiparambbs/data/editor/2505/test.jpg">
              <img src="http://down.humoruniv.com/hwiparambbs/data/editor/2505/test.jpg" />
            </a>
          </div>
          </body></html>
        ''');
        final container = doc.querySelector('.body_editor')!;

        final result = client.scanContentFull(doc, container);

        final imgs = result.blocks.whereType<ImageBlock>().toList();
        expect(imgs, hasLength(1));
      });

      test('should allow different images from different paths', () {
        final doc = html_parser.parse('''
          <html><body>
          <div class="body_editor">
            <img src="http://timg.humoruniv.com/editor/img001.jpg"
                 img_file_url="http://timg.humoruniv.com/editor/img001.jpg"
                 class="img_compress" />
          </div>
          <div class="download_area">
            <a href="download.php?url=http://down.humoruniv.com/editor/img002.jpg">
              <img src="http://down.humoruniv.com/editor/img002.jpg" />
            </a>
          </div>
          </body></html>
        ''');
        final container = doc.querySelector('.body_editor')!;

        final result = client.scanContentFull(doc, container);

        final imgs = result.blocks.whereType<ImageBlock>().toList();
        expect(imgs, hasLength(2));
      });

      test('should include both imageUrls for gallery', () {
        final doc = html_parser.parse('''
          <html><body>
          <div class="body_editor">
            <img src="http://example.com/a.jpg"
                 img_file_url="http://example.com/a.jpg"
                 class="img_compress" />
          </div>
          <div class="download_area">
            <a href="download.php?url=http://example.com/b.jpg">
              <img src="http://example.com/b_thumb.jpg" />
            </a>
          </div>
          </body></html>
        ''');
        final container = doc.querySelector('.body_editor')!;

        final result = client.scanContentFull(doc, container);

        expect(result.imageUrls, hasLength(2));
      });

      test('should skip download links inside content container', () {
        final doc = html_parser.parse('''
          <html><body>
          <div class="body_editor">
            <a href="download.php?url=http://example.com/img.jpg">
              <img src="http://example.com/img.jpg" img_file_url="http://example.com/img.jpg" class="img_compress" />
            </a>
          </div>
          </body></html>
        ''');
        final container = doc.querySelector('.body_editor')!;

        final result = client.scanContentFull(doc, container);

        final imgs = result.blocks.whereType<ImageBlock>().toList();
        expect(imgs, hasLength(1));
      });
    });

    group('daum-wm-content layout (no body_editor)', () {
      test('should extract both image and text from wrap_copy container', () {
        final doc = html_parser.parse('''
          <div class="daum-wm-content">
            <wrap_copy id="wrap_copy">
              <table width="100%" border="0" cellspacing="0" cellpadding="0">
                <tr><td align="center">
                  <div id="comment_file_file_2856297_141796028">
                    <div class="comment_img_div">
                      <img src="//timg.humoruniv.com/thumb.php?url=http://down.humoruniv.com/hwiparambbs/data/pds/test.jpg?SIZE=800x1066"
                           img_file_url="//down.humoruniv.com/hwiparambbs/data/pds/test.jpg"
                           class="img_compress" />
                    </div>
                  </div>
                </td></tr>
              </table>
              <p class="content_body_padding">
                웃긴자료 게시글 본문 텍스트입니다.
              </p>
            </wrap_copy>
          </div>
        ''');
        final container = doc.querySelector('.daum-wm-content')!;

        final result = client.scanContent(container);

        final images = result.blocks.whereType<ImageBlock>().toList();
        final texts = result.blocks.whereType<TextBlock>().toList();
        expect(images, hasLength(1));
        expect(texts, isNotEmpty);
        expect(texts.any((t) => t.text.contains('본문 텍스트')), isTrue);
      });

      test('should preserve image-before-text order in daum-wm-content', () {
        final doc = html_parser.parse('''
          <div class="daum-wm-content">
            <wrap_copy id="wrap_copy">
              <table width="100%" border="0" cellspacing="0" cellpadding="0">
                <tr><td align="center">
                  <div class="comment_img_div">
                    <img src="http://example.com/img.jpg"
                         img_file_url="http://example.com/img.jpg"
                         class="img_compress" />
                  </div>
                </td></tr>
              </table>
              <p class="content_body_padding">이미지 다음 텍스트</p>
            </wrap_copy>
          </div>
        ''');
        final container = doc.querySelector('.daum-wm-content')!;

        final result = client.scanContent(container);

        final imgIdx = result.blocks.indexWhere((b) => b is ImageBlock);
        final textIdx = result.blocks.indexWhere(
          (b) => b is TextBlock && b.text.contains('이미지 다음'),
        );
        expect(imgIdx, lessThan(textIdx));
      });
    });
  });
}
