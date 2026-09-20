import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/media_target.dart';

void main() {
  group('MediaTarget.image', () {
    test('marks any image url as image kind', () {
      final target = MediaTarget.image('https://example.com/a.jpg');
      expect(target.kind, MediaKind.image);
      expect(target.isDownloadable, isTrue);
    });
  });

  group('MediaTarget.video', () {
    test('marks a direct video url as video kind', () {
      final target = MediaTarget.video(
        const VideoBlock(url: 'https://example.com/clip.mp4'),
      );
      expect(target.kind, MediaKind.video);
      expect(target.isDownloadable, isTrue);
    });

    test('marks a youtube watch url as external embed', () {
      final target = MediaTarget.video(
        const VideoBlock(url: 'https://www.youtube.com/watch?v=abc12345678'),
      );
      expect(target.kind, MediaKind.external);
      expect(target.isDownloadable, isFalse);
    });

    test('marks a short youtu.be url as external embed', () {
      final target = MediaTarget.video(
        const VideoBlock(url: 'https://youtu.be/abc12345678'),
      );
      expect(target.kind, MediaKind.external);
    });

    test('marks a vimeo url as external embed', () {
      final target = MediaTarget.video(
        const VideoBlock(url: 'https://vimeo.com/123456'),
      );
      expect(target.kind, MediaKind.external);
    });

    test('gif-converted clips stay video kind', () {
      final target = MediaTarget.video(
        const VideoBlock(
          url: 'https://example.com/gif.mp4',
          isGifConversion: true,
        ),
      );
      expect(target.kind, MediaKind.video);
      expect(target.isDownloadable, isTrue);
    });
  });

  group('equality', () {
    test('same url and kind are equal', () {
      expect(
        MediaTarget.image('https://a/1.jpg'),
        MediaTarget.image('https://a/1.jpg'),
      );
    });

    test('different kinds are not equal', () {
      expect(
        MediaTarget.image('https://youtu.be/abc12345678'),
        isNot(
          MediaTarget.video(
            const VideoBlock(url: 'https://youtu.be/abc12345678'),
          ),
        ),
      );
    });
  });
}
