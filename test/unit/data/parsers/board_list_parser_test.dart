import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/data/parsers/board_list_parser.dart';

void main() {
  late String fixtureHtml;

  setUp(() {
    fixtureHtml = File('test/fixtures/board_list_pds.html').readAsStringSync();
  });

  group('BoardListParser', () {
    test('should return posts when html contains valid board list', () {
      final result = BoardListParser.parse(fixtureHtml);

      expect(result.posts, isNotEmpty);
      expect(result.posts.first.title, isNotEmpty);
      expect(result.posts.first.id, greaterThan(0));
    });

    test('should return empty result when html is empty string', () {
      final result = BoardListParser.parse('');

      expect(result.posts, isEmpty);
      expect(result.currentPage, equals(0));
      expect(result.totalPage, equals(0));
    });

    test('should return empty result when html has no post elements', () {
      final result = BoardListParser.parse('<html><body></body></html>');

      expect(result.posts, isEmpty);
    });

    test('should extract post id from data-number attribute', () {
      final result = BoardListParser.parse(fixtureHtml);

      expect(result.posts.first.id, greaterThan(0));
    });

    test('should extract title from link_hover span', () {
      final result = BoardListParser.parse(fixtureHtml);

      expect(result.posts.first.title, isNotEmpty);
    });

    test('should extract author from hu_nick_txt span', () {
      final result = BoardListParser.parse(fixtureHtml);

      expect(result.posts.any((p) => p.author.isNotEmpty), isTrue);
    });

    test('should extract recommend count', () {
      final result = BoardListParser.parse(fixtureHtml);

      expect(result.posts.any((p) => p.recommendCount > 0), isTrue);
    });

    test('should extract url with table and number params', () {
      final result = BoardListParser.parse(fixtureHtml);

      expect(result.posts.first.url, contains('table='));
      expect(result.posts.first.url, contains('number='));
    });

    test('should extract pagination info', () {
      final result = BoardListParser.parse(fixtureHtml);

      expect(result.currentPage, greaterThanOrEqualTo(0));
    });

    test('should extract thumbnail url from posts with images', () {
      final result = BoardListParser.parse(fixtureHtml);

      final withThumb = result.posts
          .where((p) => p.thumbnailUrl.isNotEmpty)
          .toList();
      expect(
        withThumb,
        isNotEmpty,
        reason: 'Some posts should have thumbnail URLs',
      );

      for (final post in withThumb) {
        expect(post.thumbnailUrl, contains('down.humoruniv.com'));
        expect(post.thumbnailUrl, isNot(contains('thumb.php')));
        expect(post.thumbnailUrl, isNot(contains('SIZE=')));
      }
    });

    test('should extract full-size original from thumb.php url param', () {
      final result = BoardListParser.parse(fixtureHtml);

      final withThumb = result.posts
          .where((p) => p.thumbnailUrl.isNotEmpty)
          .toList();
      expect(withThumb, isNotEmpty);

      final sample = withThumb.first.thumbnailUrl;
      expect(sample, startsWith('https://down.humoruniv.com/'));
      expect(sample, isNot(contains('?SIZE=')));
    });

    test('should return empty thumbnail for no_image posts', () {
      final result = BoardListParser.parse(fixtureHtml);

      final noThumb = result.posts
          .where((p) => p.thumbnailUrl.isEmpty)
          .toList();
      expect(
        noThumb,
        isNotEmpty,
        reason: 'Some posts should have no thumbnail',
      );
    });

    test('should parse partial results when some elements are malformed', () {
      const partialHtml = '''
      <html><body>
      <div class="post_item">
        <a class="post_link" href="/rd.html?url=/board/read.html&table=pds&number=100" data-number="100">
          <span class="link_hover">Valid Post</span>
          <span class="hu_nick_txt">user1</span>
          <span class="blk">
            <span class="ok_num">50</span>
            <span class="not_ok_num">2</span>
            <span class="comment_num">10</span>
          </span>
        </a>
      </div>
      </body></html>
      ''';

      final result = BoardListParser.parse(partialHtml);

      expect(result.posts.length, equals(1));
      expect(result.posts.first.title, equals('Valid Post'));
      expect(result.posts.first.author, equals('user1'));
      expect(result.posts.first.recommendCount, equals(50));
    });
  });
}
