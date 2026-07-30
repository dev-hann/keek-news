import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/service/parser/board_list_parser.dart';

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
        expect(post.thumbnailUrl, contains('humoruniv.com'));
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

    test(
      'video post thumbnail must NOT unwrap to raw .mp4 (server thumb.php renders PNG)',
      () {
        const videoPostHtml = '''
        <html><body>
        <div class="post_item">
          <a class="post_link" href="/rd.html?url=/board/read.html&table=pds&number=200" data-number="200">
            <span class="link_hover">Video Post</span>
            <table><tr><td>
              <img class="img" src="https://timg.humoruniv.com/thumb.php?url=https://down.humoruniv.com/hwiparambbs/data/pds/clip.mp4?SIZE=120x90" />
            </td></tr></table>
            <span class="hu_nick_txt">user2</span>
          </a>
        </div>
        </body></html>
        ''';

        final result = BoardListParser.parse(videoPostHtml);
        final thumb = result.posts.first.thumbnailUrl;

        expect(thumb, isNotEmpty);
        expect(
          thumb.startsWith('https://down.humoruniv.com/'),
          isFalse,
          reason: 'raw mp4 file URL cannot be decoded as image: $thumb',
        );
        expect(
          thumb.contains('thumb.php'),
          isTrue,
          reason:
              'video thumb should keep thumb.php form so server renders PNG',
        );
      },
    );

    test('image post thumbnail still unwraps to full-size original', () {
      const imagePostHtml = '''
      <html><body>
      <div class="post_item">
        <a class="post_link" href="/rd.html?url=/board/read.html&table=pds&number=201" data-number="201">
          <span class="link_hover">Image Post</span>
          <table><tr><td>
            <img class="img" src="https://timg.humoruniv.com/thumb.php?url=https://down.humoruniv.com/hwiparambbs/data/pds/photo.jpg?SIZE=120x90" />
          </td></tr></table>
          <span class="hu_nick_txt">user3</span>
        </a>
      </div>
      </body></html>
      ''';

      final result = BoardListParser.parse(imagePostHtml);
      final thumb = result.posts.first.thumbnailUrl;

      expect(
        thumb,
        'https://down.humoruniv.com/hwiparambbs/data/pds/photo.jpg',
      );
    });
  });
}
