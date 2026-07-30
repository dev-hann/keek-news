import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/service/parser/post_detail_parser.dart';

void main() {
  group('PostDetailParser content coverage', () {
    group('daum-wm-content fallback', () {
      test(
        'should parse content from daum-wm-content when body_editor missing',
        () {
          const html = '''
        <html><head><title>DAUM Test</title></head><body>
        <div id="read_profile_td"><span class="hu_nick_txt">user</span></div>
        <div id="read_profile_desc"><span class="etc">작성 2026-05-17 11:00:00</span></div>
        <div class="daum-wm-content">
          <div class="wrap_img">
            <div id="comment_file_123">
              <img src="//down-webp.humoruniv.com/89/test.webp"
                   img_file_url="//down.humoruniv.com/hwiparambbs/data/pds/test.jpg"
                   class="img_compress img_bb" />
            </div>
          </div>
          <p class="content_body_padding"></p>
        </div>
        </body></html>
        ''';

          final result = PostDetailParser.parse(html);

          expect(result.contentBlocks, isNotEmpty);
          expect(result.contentBlocks.any((b) => b is ImageBlock), isTrue);
          expect(result.imageUrls, isNotEmpty);
          expect(result.contentHtml, isNotEmpty);
        },
      );

      test(
        'should prefer body_editor over daum-wm-content when both exist',
        () {
          const html = '''
        <html><head><title>Both Test</title></head><body>
        <div id="read_profile_td"><span class="hu_nick_txt">user</span></div>
        <div id="read_profile_desc"><span class="etc">작성 2026-05-17 11:00:00</span></div>
        <div class="body_editor">
          <div class="simple_attach_img_div">에디터 본문</div>
        </div>
        <div class="daum-wm-content">
          <p class="content_body_padding">다음 컨텐츠</p>
        </div>
        </body></html>
        ''';

          final result = PostDetailParser.parse(html);

          expect(result.contentBlocks, isNotEmpty);
          expect(
            result.contentBlocks.whereType<TextBlock>().any(
              (b) => b.text.contains('에디터'),
            ),
            isTrue,
          );
        },
      );
    });

    group('download.php images', () {
      test('should extract image URLs from download.php links', () {
        const html = '''
        <html><head><title>Download Test</title></head><body>
        <div id="read_profile_td"><span class="hu_nick_txt">user</span></div>
        <div id="read_profile_desc"><span class="etc">작성 2026-05-17 11:00:00</span></div>
        <div class="body_editor"><p>본문 내용</p></div>
        <div id="list_download">
          <span id="list_download_1">
            <a href="download.php?url=https://down.humoruniv.com/hwiparambbs/data/pds/a_w001_test.jpg&table=pds&number=1410190&tail=001&download_token_one=123">
              <div id="item_download" class="pointer">
                <div id="item_toggle_001">
                  <img src="https://timg.humoruniv.com/thumb.php?url=https://down.humoruniv.com/hwiparambbs/data/pds/a_w001_test.jpg?SIZE=70x40" class="gbd1">
                  <span>001.jpg</span>
                </div>
              </div>
            </a>
          </span>
        </div>
        </body></html>
        ''';

        final result = PostDetailParser.parse(html);

        expect(result.imageUrls, contains(contains('a_w001_test.jpg')));
        final imageBlocks = result.contentBlocks
            .whereType<ImageBlock>()
            .toList();
        expect(
          imageBlocks.any((b) => b.url.contains('a_w001_test.jpg')),
          isTrue,
        );
      });
    });

    group('img_file_url extraction', () {
      test('should prefer img_file_url over src for original image', () {
        const html = '''
        <html><head><title>URL Priority</title></head><body>
        <div id="read_profile_td"><span class="hu_nick_txt">user</span></div>
        <div id="read_profile_desc"><span class="etc">작성 2026-05-17 11:00:00</span></div>
        <div class="body_editor">
          <div class="simple_attach_img_div">
            <img src="//timg.humoruniv.com/thumb.php?url=https://down.humoruniv.com/test.jpg?SIZE=200x200"
                 img_file_url="https://down.humoruniv.com/test.jpg"
                 class="img_compress" />
          </div>
        </div>
        </body></html>
        ''';

        final result = PostDetailParser.parse(html);

        final imageBlocks = result.contentBlocks
            .whereType<ImageBlock>()
            .toList();
        expect(imageBlocks, hasLength(1));
        expect(
          imageBlocks.first.url,
          equals('https://down.humoruniv.com/test.jpg'),
        );
        expect(imageBlocks.first.thumbnailUrl, contains('thumb.php'));
      });

      test('should extract img_bb webp images with fallback', () {
        const html = '''
        <html><head><title>WebP Test</title></head><body>
        <div id="read_profile_td"><span class="hu_nick_txt">user</span></div>
        <div id="read_profile_desc"><span class="etc">작성 2026-05-17 11:00:00</span></div>
        <div class="body_editor">
          <div class="comment_img_div">
            <img src="//down-webp.humoruniv.com/89/abc.webp"
                 img_file_url="//down.humoruniv.com/hwiparambbs/data/pds/abc.jpg"
                 class="img_compress img_bb" />
          </div>
        </div>
        </body></html>
        ''';

        final result = PostDetailParser.parse(html);

        final imageBlocks = result.contentBlocks
            .whereType<ImageBlock>()
            .toList();
        expect(imageBlocks, hasLength(1));
        expect(
          imageBlocks.first.url,
          contains('down.humoruniv.com/hwiparambbs'),
        );
      });
    });

    group('YouTube link detection', () {
      test('should detect youtu.be link in autolink span as VideoBlock', () {
        const html = '''
        <html><head><title>YouTube Test</title></head><body>
        <div id="read_profile_td"><span class="hu_nick_txt">user</span></div>
        <div id="read_profile_desc"><span class="etc">작성 2026-05-17 11:00:00</span></div>
        <div class="body_editor">
          <p>영상 보세요</p>
          <span class="autolink"><a href="https://youtu.be/gJbvzUV8624?si=test">https://youtu.be/gJbvzUV8624?si=test</a></span>
        </div>
        </body></html>
        ''';

        final result = PostDetailParser.parse(html);

        final videoBlocks = result.contentBlocks
            .whereType<VideoBlock>()
            .toList();
        expect(videoBlocks, isNotEmpty);
        expect(
          videoBlocks.first.url,
          contains('youtube.com/watch?v=gJbvzUV8624'),
        );
        expect(
          videoBlocks.first.thumbnailUrl,
          contains('img.youtube.com/vi/gJbvzUV8624'),
        );
      });

      test('should detect youtube.com/watch URL in autolink', () {
        const html = '''
        <html><head><title>YouTube Watch</title></head><body>
        <div id="read_profile_td"><span class="hu_nick_txt">user</span></div>
        <div id="read_profile_desc"><span class="etc">작성 2026-05-17 11:00:00</span></div>
        <div class="body_editor">
          <span class="autolink"><a href="https://www.youtube.com/watch?v=abc12345678">유튜브 영상</a></span>
        </div>
        </body></html>
        ''';

        final result = PostDetailParser.parse(html);

        final videoBlocks = result.contentBlocks
            .whereType<VideoBlock>()
            .toList();
        expect(videoBlocks, isNotEmpty);
        expect(videoBlocks.first.url, contains('v=abc12345678'));
      });
    });

    group('comment images', () {
      test('should extract image URLs from comment items', () {
        const html = '''
        <html><head><title>Comment Image</title></head><body>
        <div id="read_profile_td"><span class="hu_nick_txt">author</span></div>
        <div id="read_profile_desc"><span class="etc">작성 2026-05-17 11:00:00</span></div>
        <div class="body_editor"><p>content</p></div>
        <ul>
          <li id="comment_li_100">
            <div class="bg_gray">
              <span class="hu_nick_txt">commenter</span>
            </div>
            <span class="comment_body">
              <div class="wrap_img">
                <div id="comment_file_200" style="width:100%;">
                  <div class="comment_img_div">
                    <img src="//down-webp.humoruniv.com/20/test.webp"
                         img_file_url="https://down.humoruniv.com/hwiparambbs/data/editor/test.jpg"
                         class="img_compress img_bb" />
                  </div>
                </div>
              </div>
              <span class="comment_text">댓글 내용</span>
            </span>
            <span class="etc">2026-05-17 12:00:00</span>
            <span class="o">5</span>
          </li>
        </ul>
        </body></html>
        ''';

        final result = PostDetailParser.parse(html);

        expect(result.comments, isNotEmpty);
        expect(result.comments.first.imageUrls, isNotEmpty);
        expect(
          result.comments.first.imageUrls.first,
          contains('hwiparambbs/data/editor/test.jpg'),
        );
      });
    });

    group('HtmlBlock for rich content', () {
      test('should produce HtmlBlock for element with bold and links', () {
        const html = '''
        <html><head><title>Rich Test</title></head><body>
        <div id="read_profile_td"><span class="hu_nick_txt">user</span></div>
        <div id="read_profile_desc"><span class="etc">작성 2026-05-17 11:00:00</span></div>
        <div class="body_editor">
          <div>
            <b>굵은 텍스트</b>와 일반 텍스트
            <a href="https://example.com">링크</a>
          </div>
        </div>
        </body></html>
        ''';

        final result = PostDetailParser.parse(html);

        expect(result.contentBlocks.any((b) => b is HtmlBlock), isTrue);
        final htmlBlock = result.contentBlocks.whereType<HtmlBlock>().first;
        expect(htmlBlock.html, contains('<b>'));
        expect(htmlBlock.html, contains('href'));
      });
    });

    group('JS template video rejection', () {
      test('should skip video tags with JS template variables', () {
        const html = '''
        <html><head><title>JS Video</title></head><body>
        <div id="read_profile_td"><span class="hu_nick_txt">user</span></div>
        <div id="read_profile_desc"><span class="etc">작성 2026-05-17 11:00:00</span></div>
        <div class="body_editor">
          <div class="simple_attach_img_div">
            <video id="video_mp4_"+comment_number+"' width='"+width+"' height='"+height+"' poster='"+thumb_url+"' controls>
              <source src="'+mp4_url+'" type="video/mp4">
            </video>
          </div>
        </div>
        </body></html>
        ''';

        final result = PostDetailParser.parse(html);

        expect(result.contentBlocks.whereType<VideoBlock>().isEmpty, isTrue);
      });
    });
  });
}
