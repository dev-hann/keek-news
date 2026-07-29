import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/data/parsers/main_page_parser.dart';

void main() {
  group('MainPageParser edge cases', () {
    test('should handle href with missing url param', () {
      const html = '''
      <html><body>
      <a href="/rd.html?table=pds&number=123">
        <li id="pds_best_li_123">
          <span id="title_chk_pds-123">Post</span>
          <em>10</em>
        </li>
      </a>
      </body></html>
      ''';

      final result = MainPageParser.parseBestPosts(html);

      expect(result, hasLength(1));
      expect(result.first.url, isNotEmpty);
    });

    test('should handle href with missing table param', () {
      const html = '''
      <html><body>
      <a href="/rd.html?url=/board/read.html&number=123">
        <li id="pds_best_li_123">
          <span id="title_chk_pds-123">Post</span>
          <em>10</em>
        </li>
      </a>
      </body></html>
      ''';

      final result = MainPageParser.parseBestPosts(html);

      expect(result, hasLength(1));
    });

    test('should handle empty href', () {
      const html = '''
      <html><body>
      <a href="">
        <li id="pds_best_li_123">
          <span id="title_chk_pds-123">Post</span>
          <em>10</em>
        </li>
      </a>
      </body></html>
      ''';

      final result = MainPageParser.parseBestPosts(html);

      expect(result, hasLength(1));
      expect(result.first.url, isEmpty);
    });

    test('should handle li without parent anchor', () {
      const html = '''
      <html><body>
      <li id="pds_best_li_123">
        <span id="title_chk_pds-123">Orphan Post</span>
        <em>5</em>
      </li>
      </body></html>
      ''';

      final result = MainPageParser.parseBestPosts(html);

      expect(result, hasLength(1));
      expect(result.first.title, 'Orphan Post');
      expect(result.first.url, isEmpty);
    });
  });
}
