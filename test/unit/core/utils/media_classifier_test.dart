import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/utils/media_classifier.dart';

void main() {
  group('MediaClassifier', () {
    group('classify', () {
      test('should classify .jpg as image', () {
        expect(
          MediaClassifier.classify('http://example.com/photo.jpg'),
          MediaType.image,
        );
      });

      test('should classify .jpeg as image', () {
        expect(
          MediaClassifier.classify('http://example.com/photo.jpeg'),
          MediaType.image,
        );
      });

      test('should classify .png as image', () {
        expect(
          MediaClassifier.classify('http://example.com/icon.png'),
          MediaType.image,
        );
      });

      test('should classify .gif as image', () {
        expect(
          MediaClassifier.classify('http://example.com/anim.gif'),
          MediaType.image,
        );
      });

      test('should classify .webp as image', () {
        expect(
          MediaClassifier.classify('http://example.com/photo.webp'),
          MediaType.image,
        );
      });

      test('should classify .bmp as image', () {
        expect(
          MediaClassifier.classify('http://example.com/photo.bmp'),
          MediaType.image,
        );
      });

      test('should classify .mp4 as video', () {
        expect(
          MediaClassifier.classify('http://example.com/video.mp4'),
          MediaType.video,
        );
      });

      test('should classify .webm as video', () {
        expect(
          MediaClassifier.classify('http://example.com/video.webm'),
          MediaType.video,
        );
      });

      test('should classify .mov as video', () {
        expect(
          MediaClassifier.classify('http://example.com/video.mov'),
          MediaType.video,
        );
      });

      test('should classify .mp3 as audio', () {
        expect(
          MediaClassifier.classify('http://example.com/audio.mp3'),
          MediaType.audio,
        );
      });

      test('should classify .wav as audio', () {
        expect(
          MediaClassifier.classify('http://example.com/audio.wav'),
          MediaType.audio,
        );
      });

      test('should classify YouTube watch URL as youtube', () {
        expect(
          MediaClassifier.classify(
            'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          ),
          MediaType.youtube,
        );
      });

      test('should classify YouTube short URL as youtube', () {
        expect(
          MediaClassifier.classify('https://youtu.be/dQw4w9WgXcQ'),
          MediaType.youtube,
        );
      });

      test('should classify YouTube embed URL as youtube', () {
        expect(
          MediaClassifier.classify('https://www.youtube.com/embed/dQw4w9WgXcQ'),
          MediaType.youtube,
        );
      });

      test('should classify download.php wrapping .mp4 as video', () {
        expect(
          MediaClassifier.classify(
            'http://down.humoruniv.com/download.php?url=http://example.com/video.mp4',
          ),
          MediaType.video,
        );
      });

      test('should classify download.php wrapping .jpg as image', () {
        expect(
          MediaClassifier.classify(
            'http://down.humoruniv.com/download.php?url=http://example.com/photo.jpg',
          ),
          MediaType.image,
        );
      });

      test('should classify regular http URL as link', () {
        expect(
          MediaClassifier.classify('https://example.com/page'),
          MediaType.link,
        );
      });

      test('should return unknown for empty string', () {
        expect(MediaClassifier.classify(''), MediaType.unknown);
      });

      test('should be case insensitive for extensions', () {
        expect(
          MediaClassifier.classify('http://example.com/PHOTO.JPG'),
          MediaType.image,
        );
        expect(
          MediaClassifier.classify('http://example.com/VIDEO.MP4'),
          MediaType.video,
        );
      });
    });

    group('unwrapDownloadPhp', () {
      test('should unwrap download.php URL', () {
        final result = MediaClassifier.unwrapDownloadPhp(
          'http://down.humoruniv.com/download.php?url=http://example.com/photo.jpg',
        );
        expect(result, 'http://example.com/photo.jpg');
      });

      test('should return null for non-download URL', () {
        final result = MediaClassifier.unwrapDownloadPhp(
          'http://example.com/photo.jpg',
        );
        expect(result, isNull);
      });

      test('should return null for empty string', () {
        final result = MediaClassifier.unwrapDownloadPhp('');
        expect(result, isNull);
      });
    });

    group('extractYoutubeId', () {
      test('should extract ID from watch URL', () {
        expect(
          MediaClassifier.extractYoutubeId(
            'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          ),
          'dQw4w9WgXcQ',
        );
      });

      test('should extract ID from short URL', () {
        expect(
          MediaClassifier.extractYoutubeId('https://youtu.be/dQw4w9WgXcQ'),
          'dQw4w9WgXcQ',
        );
      });

      test('should extract ID from embed URL', () {
        expect(
          MediaClassifier.extractYoutubeId(
            'https://www.youtube.com/embed/dQw4w9WgXcQ',
          ),
          'dQw4w9WgXcQ',
        );
      });

      test('should return null for non-YouTube URL', () {
        expect(
          MediaClassifier.extractYoutubeId('https://example.com/video.mp4'),
          isNull,
        );
      });
    });

    group('isMedia', () {
      test('should return true for image URLs', () {
        expect(MediaClassifier.isMedia('http://example.com/photo.jpg'), isTrue);
      });

      test('should return true for video URLs', () {
        expect(MediaClassifier.isMedia('http://example.com/video.mp4'), isTrue);
      });

      test('should return true for YouTube URLs', () {
        expect(
          MediaClassifier.isMedia(
            'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          ),
          isTrue,
        );
      });

      test('should return true for audio URLs', () {
        expect(MediaClassifier.isMedia('http://example.com/audio.mp3'), isTrue);
      });

      test('should return false for regular links', () {
        expect(MediaClassifier.isMedia('https://example.com/page'), isFalse);
      });

      test('should return false for unknown', () {
        expect(MediaClassifier.isMedia(''), isFalse);
      });
    });
  });
}
