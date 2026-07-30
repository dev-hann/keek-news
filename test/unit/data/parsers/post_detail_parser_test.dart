import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/data/parsers/post_detail_parser.dart';
import 'package:happy_news/domain/entities/content_block.dart';

void main() {
  late String fixtureHtml;

  setUpAll(() {
    fixtureHtml = File('test/fixtures/post_detail.html').readAsStringSync();
  });

  test('should parse title from fixture', () {
    final result = PostDetailParser.parse(fixtureHtml);

    expect(result.title, isNotEmpty);
    expect(result.title, contains('MBC PD'));
  });

  test('should parse author nickname', () {
    final result = PostDetailParser.parse(fixtureHtml);

    expect(result.author, isNotEmpty);
    expect(result.author, equals('오유의감동브레이커'));
  });

  test('should parse post date', () {
    final result = PostDetailParser.parse(fixtureHtml);

    expect(result.date.year, 2026);
    expect(result.date.month, 5);
    expect(result.date.day, 15);
  });

  test('should parse recommend count', () {
    final result = PostDetailParser.parse(fixtureHtml);

    expect(result.recommendCount, greaterThan(0));
  });

  test('should parse not-recommend count', () {
    final result = PostDetailParser.parse(fixtureHtml);

    expect(result.notRecommendCount, greaterThanOrEqualTo(0));
  });

  test('should parse view count', () {
    final result = PostDetailParser.parse(fixtureHtml);

    expect(result.viewCount, greaterThan(0));
  });

  test('should parse view count from ic_view span, not the date year', () {
    const html = '''
    <html><head><title>t</title></head><body>
    <div id="read_profile_td"><span class="hu_nick_txt">user</span></div>
    <p id="read_profile_desc">
      <span class="etc">작성 2026-07-29 12:50:22</span>
      <br><span class="etc">이동 2026-07-30 07:23:34</span>
      <br>
      <span class="ok"><img src="/images/ic_ok.png"> <span id="ok_div">242</span></span>
      <span class="notok"><img src="/images/ic_not_ok.png"> <span id="not_ok_span">0</span></span>
      <span class="comment_num"><img src="/images/ic_re.png"> 21</span>
      <span class="etc"><img src="/images/ic_view.png"> 18,504</span>
    </p>
    </body></html>
    ''';

    final result = PostDetailParser.parse(html);

    expect(
      result.viewCount,
      18504,
      reason: '조회수는 ic_view span의 값이어야 함 (작성일 연도 2026이 아님)',
    );
  });

  test('should parse comment count', () {
    final result = PostDetailParser.parse(fixtureHtml);

    expect(result.commentCount, greaterThan(0));
  });

  test('should extract image URLs from body', () {
    final result = PostDetailParser.parse(fixtureHtml);

    expect(result.imageUrls, isNotEmpty);
    expect(result.imageUrls.first, contains('humoruniv.com'));
  });

  test('should extract content blocks with text and images', () {
    final result = PostDetailParser.parse(fixtureHtml);

    expect(result.contentBlocks, isNotEmpty);
    final hasText = result.contentBlocks.any((b) => b is TextBlock);
    final hasImage = result.contentBlocks.any((b) => b is ImageBlock);
    expect(hasText || hasImage, isTrue);
  });

  test('should extract comments including best comments', () {
    final result = PostDetailParser.parse(fixtureHtml);

    expect(result.comments, isNotEmpty);
    final bestComments = result.comments.where((c) => c.isBest).toList();
    expect(bestComments, isNotEmpty);
  });

  test('should return empty detail when html is empty string', () {
    final result = PostDetailParser.parse('');

    expect(result.title, isEmpty);
    expect(result.author, isEmpty);
    expect(result.comments, isEmpty);
    expect(result.imageUrls, isEmpty);
  });

  test('should return empty detail when html has no post elements', () {
    final result = PostDetailParser.parse('<html><body>nothing</body></html>');

    expect(result.title, isEmpty);
    expect(result.comments, isEmpty);
  });

  test('should extract text outside simple_attach_img_div', () {
    const html = '''
    <html><head><title>Test</title></head><body>
    <div id="read_profile_td"><span class="hu_nick_txt">user</span></div>
    <div id="read_profile_desc"><span class="etc">작성 2026-05-15 11:00:00</span></div>
    <div class="body_editor">
      Text before divs
      <div class="simple_attach_img_div">
        <img src="http://example.com/img.jpg" img_file_url="http://example.com/img.jpg" class="img_compress" />
      </div>
      Text between divs
      <div class="simple_attach_img_div">Last text</div>
      Text after divs
    </div>
    </body></html>
    ''';

    final result = PostDetailParser.parse(html);

    final texts = result.contentBlocks
        .whereType<TextBlock>()
        .map((b) => b.text)
        .toList();
    expect(texts, contains('Text before divs'));
    expect(texts, contains('Text after divs'));
  });

  test('should not produce empty TextBlocks from br-only divs', () {
    const html = '''
    <html><head><title>Test</title></head><body>
    <div id="read_profile_td"><span class="hu_nick_txt">user</span></div>
    <div id="read_profile_desc"><span class="etc">작성 2026-05-15 11:00:00</span></div>
    <div class="body_editor">
      <div class="simple_attach_img_div"><br></div>
      <div class="simple_attach_img_div"><br></div>
      <div class="simple_attach_img_div">실제 텍스트</div>
    </div>
    </body></html>
    ''';

    final result = PostDetailParser.parse(html);

    final emptyBlocks = result.contentBlocks.whereType<TextBlock>().where(
      (b) => b.text.trim().isEmpty,
    );
    expect(emptyBlocks, isEmpty);
  });

  test('should detect video tag as VideoBlock', () {
    const html = '''
    <html><head><title>Test</title></head><body>
    <div id="read_profile_td"><span class="hu_nick_txt">user</span></div>
    <div id="read_profile_desc"><span class="etc">작성 2026-05-15 11:00:00</span></div>
    <div class="body_editor">
      <div class="simple_attach_img_div">
        <video width="480" height="360" poster="http://example.com/thumb.jpg" controls loop muted autoplay playsinline>
          <source src="http://example.com/video.mp4" type="video/mp4">
        </video>
      </div>
    </div>
    </body></html>
    ''';

    final result = PostDetailParser.parse(html);

    expect(result.contentBlocks.any((b) => b is VideoBlock), isTrue);
    final video = result.contentBlocks.whereType<VideoBlock>().first;
    expect(video.url, 'http://example.com/video.mp4');
    expect(video.thumbnailUrl, 'http://example.com/thumb.jpg');
    expect(video.width, 480);
    expect(video.height, 360);
  });

  test('should detect video embed div with mp4 data attributes', () {
    const html = '''
    <html><head><title>Test</title></head><body>
    <div id="read_profile_td"><span class="hu_nick_txt">user</span></div>
    <div id="read_profile_desc"><span class="etc">작성 2026-05-15 11:00:00</span></div>
    <div class="body_editor">
      <div class="comment_img_div">
        <div id="embed_div">
          <video width="348" height="348" poster="http://example.com/thumb.jpg" preload="auto" controls loop muted autoplay playsinline>
            <source src="http://example.com/anim.mp4" type="video/mp4">
          </video>
        </div>
      </div>
    </div>
    </body></html>
    ''';

    final result = PostDetailParser.parse(html);

    expect(result.contentBlocks.any((b) => b is VideoBlock), isTrue);
  });
}
