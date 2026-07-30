import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/content_block.dart';

void main() {
  group('TextBlock', () {
    test('should create with text', () {
      const block = TextBlock('hello');

      expect(block.text, 'hello');
    });

    test('should support value equality when text matches', () {
      const a = TextBlock('same');
      const b = TextBlock('same');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('should not be equal when text differs', () {
      const a = TextBlock('aaa');
      const b = TextBlock('bbb');

      expect(a, isNot(equals(b)));
    });

    test('should handle empty text', () {
      const block = TextBlock('');

      expect(block.text, '');
    });

    test('should not be equal to ImageBlock', () {
      const text = TextBlock('hello');
      const image = ImageBlock(url: 'http://example.com/img.jpg');

      expect(text, isNot(equals(image)));
    });

    test('should be equal to itself', () {
      const a = TextBlock('self');

      expect(a, equals(a));
    });
  });

  group('ImageBlock', () {
    test('should create with required url', () {
      const block = ImageBlock(url: 'http://example.com/img.jpg');

      expect(block.url, 'http://example.com/img.jpg');
      expect(block.thumbnailUrl, isNull);
    });

    test('should create with optional thumbnailUrl', () {
      const block = ImageBlock(
        url: 'http://example.com/img.jpg',
        thumbnailUrl: 'http://example.com/thumb.jpg',
      );

      expect(block.thumbnailUrl, 'http://example.com/thumb.jpg');
    });

    test('should support value equality when url and thumbnailUrl match', () {
      const a = ImageBlock(
        url: 'http://x.com/a.jpg',
        thumbnailUrl: 'http://x.com/t.jpg',
      );
      const b = ImageBlock(
        url: 'http://x.com/a.jpg',
        thumbnailUrl: 'http://x.com/t.jpg',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('should not be equal when url differs', () {
      const a = ImageBlock(url: 'http://x.com/a.jpg');
      const b = ImageBlock(url: 'http://x.com/b.jpg');

      expect(a, isNot(equals(b)));
    });

    test('should not be equal when thumbnailUrl differs', () {
      const a = ImageBlock(
        url: 'http://x.com/a.jpg',
        thumbnailUrl: 'http://x.com/ta.jpg',
      );
      const b = ImageBlock(
        url: 'http://x.com/a.jpg',
        thumbnailUrl: 'http://x.com/tb.jpg',
      );

      expect(a, isNot(equals(b)));
    });

    test(
      'should not be equal when one has null thumbnailUrl and other does not',
      () {
        const a = ImageBlock(url: 'http://x.com/a.jpg');
        const b = ImageBlock(
          url: 'http://x.com/a.jpg',
          thumbnailUrl: 'http://x.com/t.jpg',
        );

        expect(a, isNot(equals(b)));
      },
    );

    test('should be equal when both have null thumbnailUrl', () {
      const a = ImageBlock(url: 'http://x.com/a.jpg');
      const b = ImageBlock(url: 'http://x.com/a.jpg');

      expect(a, equals(b));
    });

    test('should not be equal to TextBlock', () {
      const image = ImageBlock(url: 'http://x.com/a.jpg');
      const text = TextBlock('http://x.com/a.jpg');

      expect(image, isNot(equals(text)));
    });
  });

  group('VideoBlock', () {
    test('should create with required url', () {
      const block = VideoBlock(url: 'http://example.com/video.mp4');

      expect(block.url, 'http://example.com/video.mp4');
      expect(block.thumbnailUrl, isNull);
      expect(block.width, isNull);
      expect(block.height, isNull);
      expect(block.isGifConversion, isFalse);
    });

    test('should create with all optional fields', () {
      const block = VideoBlock(
        url: 'http://example.com/video.mp4',
        thumbnailUrl: 'http://example.com/thumb.jpg',
        width: 480,
        height: 360,
        isGifConversion: true,
      );

      expect(block.thumbnailUrl, 'http://example.com/thumb.jpg');
      expect(block.width, 480);
      expect(block.height, 360);
      expect(block.isGifConversion, isTrue);
    });

    test('should support value equality when all fields match', () {
      const a = VideoBlock(
        url: 'http://x.com/v.mp4',
        thumbnailUrl: 'http://x.com/t.jpg',
        width: 480,
        height: 360,
      );
      const b = VideoBlock(
        url: 'http://x.com/v.mp4',
        thumbnailUrl: 'http://x.com/t.jpg',
        width: 480,
        height: 360,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('should not be equal when url differs', () {
      const a = VideoBlock(url: 'http://x.com/a.mp4');
      const b = VideoBlock(url: 'http://x.com/b.mp4');

      expect(a, isNot(equals(b)));
    });

    test('should not be equal when isGifConversion differs', () {
      const a = VideoBlock(url: 'http://x.com/v.mp4');
      const b = VideoBlock(url: 'http://x.com/v.mp4', isGifConversion: true);

      expect(a, isNot(equals(b)));
    });

    test('should not be equal to ImageBlock', () {
      const video = VideoBlock(url: 'http://x.com/v.mp4');
      const image = ImageBlock(url: 'http://x.com/v.mp4');

      expect(video, isNot(equals(image)));
    });

    test('should not be equal to TextBlock', () {
      const video = VideoBlock(url: 'http://x.com/v.mp4');
      const text = TextBlock('http://x.com/v.mp4');

      expect(video, isNot(equals(text)));
    });
  });
}
