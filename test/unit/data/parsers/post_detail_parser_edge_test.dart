import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/data/parsers/post_detail_parser.dart';
import 'package:happy_news/domain/entities/content_block.dart';

void main() {
  group('PostDetailParser edge cases', () {
    test('should handle malformed date gracefully', () {
      const html = '''
      <html><head><title>Test</title></head><body>
      <div id="read_profile_td"><span class="hu_nick_txt">user</span></div>
      <div id="read_profile_desc"><span class="etc">작성 not-a-date</span></div>
      <div class="body_editor"><p>content</p></div>
      </body></html>
      ''';

      final result = PostDetailParser.parse(html);

      expect(result.date.year, 1970);
    });

    test('should handle missing date element', () {
      const html = '''
      <html><head><title>Test</title></head><body>
      <div id="read_profile_td"><span class="hu_nick_txt">user</span></div>
      <div class="body_editor"><p>content</p></div>
      </body></html>
      ''';

      final result = PostDetailParser.parse(html);

      expect(result.date.year, 1970);
    });

    test('should handle view count with comma-formatted numbers', () {
      const html = '''
      <html><head><title>Test</title></head><body>
      <div id="read_profile_td"><span class="hu_nick_txt">user</span></div>
      <div id="read_profile_desc">
        <span class="etc">작성 2026-05-15 11:00:00</span>
        <span class="etc">조회 36,491</span>
      </div>
      <div class="body_editor"><p>content</p></div>
      </body></html>
      ''';

      final result = PostDetailParser.parse(html);

      expect(result.viewCount, greaterThan(0));
    });

    test('should handle empty body_editor', () {
      const html = '''
      <html><head><title>Test</title></head><body>
      <div id="read_profile_td"><span class="hu_nick_txt">user</span></div>
      <div id="read_profile_desc"><span class="etc">작성 2026-05-15 11:00:00</span></div>
      <div class="body_editor"></div>
      </body></html>
      ''';

      final result = PostDetailParser.parse(html);

      expect(result.contentBlocks, isEmpty);
      expect(result.imageUrls, isEmpty);
    });

    test('should extract text content when no image divs exist', () {
      const html = '''
      <html><head><title>Test</title></head><body>
      <div id="read_profile_td"><span class="hu_nick_txt">user</span></div>
      <div id="read_profile_desc"><span class="etc">작성 2026-05-15 11:00:00</span></div>
      <div class="body_editor"><p>Just text content</p></div>
      </body></html>
      ''';

      final result = PostDetailParser.parse(html);

      expect(result.contentBlocks, isNotEmpty);
      expect(result.contentBlocks.any((b) => b is TextBlock), isTrue);
    });
  });
}
