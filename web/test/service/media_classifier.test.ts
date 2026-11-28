import { describe, expect, it } from 'vitest';
import {
  classify,
  extractYoutubeId,
  isLoadableImage,
  isMedia,
  unwrapDownloadPhp,
} from '../../src/service/media_classifier';

describe('MediaClassifier', () => {
  describe('classify', () => {
    it('should classify .jpg as image', () => {
      expect(classify('http://example.com/photo.jpg')).toBe('image');
    });

    it('should classify .jpeg as image', () => {
      expect(classify('http://example.com/photo.jpeg')).toBe('image');
    });

    it('should classify .png as image', () => {
      expect(classify('http://example.com/icon.png')).toBe('image');
    });

    it('should classify .gif as image', () => {
      expect(classify('http://example.com/anim.gif')).toBe('image');
    });

    it('should classify .webp as image', () => {
      expect(classify('http://example.com/photo.webp')).toBe('image');
    });

    it('should classify .bmp as image', () => {
      expect(classify('http://example.com/photo.bmp')).toBe('image');
    });

    it('should classify .mp4 as video', () => {
      expect(classify('http://example.com/video.mp4')).toBe('video');
    });

    it('should classify .webm as video', () => {
      expect(classify('http://example.com/video.webm')).toBe('video');
    });

    it('should classify .mov as video', () => {
      expect(classify('http://example.com/video.mov')).toBe('video');
    });

    it('should classify .mp3 as audio', () => {
      expect(classify('http://example.com/audio.mp3')).toBe('audio');
    });

    it('should classify .wav as audio', () => {
      expect(classify('http://example.com/audio.wav')).toBe('audio');
    });

    it('should classify YouTube watch URL as youtube', () => {
      expect(classify('https://www.youtube.com/watch?v=dQw4w9WgXcQ')).toBe('youtube');
    });

    it('should classify YouTube short URL as youtube', () => {
      expect(classify('https://youtu.be/dQw4w9WgXcQ')).toBe('youtube');
    });

    it('should classify YouTube embed URL as youtube', () => {
      expect(classify('https://www.youtube.com/embed/dQw4w9WgXcQ')).toBe('youtube');
    });

    it('should classify download.php wrapping .mp4 as video', () => {
      expect(
        classify('http://down.humoruniv.com/download.php?url=http://example.com/video.mp4')
      ).toBe('video');
    });

    it('should classify download.php wrapping .jpg as image', () => {
      expect(
        classify('http://down.humoruniv.com/download.php?url=http://example.com/photo.jpg')
      ).toBe('image');
    });

    it('should classify regular http URL as link', () => {
      expect(classify('https://example.com/page')).toBe('link');
    });

    it('should return unknown for empty string', () => {
      expect(classify('')).toBe('unknown');
    });

    it('should be case insensitive for extensions', () => {
      expect(classify('http://example.com/PHOTO.JPG')).toBe('image');
      expect(classify('http://example.com/VIDEO.MP4')).toBe('video');
    });
  });

  describe('unwrapDownloadPhp', () => {
    it('should unwrap download.php URL', () => {
      const result = unwrapDownloadPhp(
        'http://down.humoruniv.com/download.php?url=http://example.com/photo.jpg'
      );
      expect(result).toBe('http://example.com/photo.jpg');
    });

    it('should return null for non-download URL', () => {
      const result = unwrapDownloadPhp('http://example.com/photo.jpg');
      expect(result).toBeNull();
    });

    it('should return null for empty string', () => {
      const result = unwrapDownloadPhp('');
      expect(result).toBeNull();
    });
  });

  describe('extractYoutubeId', () => {
    it('should extract ID from watch URL', () => {
      expect(extractYoutubeId('https://www.youtube.com/watch?v=dQw4w9WgXcQ')).toBe('dQw4w9WgXcQ');
    });

    it('should extract ID from short URL', () => {
      expect(extractYoutubeId('https://youtu.be/dQw4w9WgXcQ')).toBe('dQw4w9WgXcQ');
    });

    it('should extract ID from embed URL', () => {
      expect(extractYoutubeId('https://www.youtube.com/embed/dQw4w9WgXcQ')).toBe('dQw4w9WgXcQ');
    });

    it('should return null for non-YouTube URL', () => {
      expect(extractYoutubeId('https://example.com/video.mp4')).toBeNull();
    });
  });

  describe('isLoadableImage', () => {
    it('should return false for .mp4 video URL', () => {
      expect(isLoadableImage('https://example.com/clip.mp4')).toBe(false);
    });

    it('should return false for .webm video URL', () => {
      expect(isLoadableImage('https://example.com/clip.webm')).toBe(false);
    });

    it('should return true for .jpg image URL', () => {
      expect(isLoadableImage('https://example.com/photo.jpg')).toBe(true);
    });

    it('should return true for .jpg with query string', () => {
      expect(isLoadableImage('https://example.com/photo.jpg?SIZE=70x40')).toBe(true);
    });

    it('should return false for .svg (no decoder in app)', () => {
      expect(isLoadableImage('https://example.com/icon.svg')).toBe(false);
    });

    it('should return false for humoruniv url_enc encrypted thumb', () => {
      expect(isLoadableImage('https://timg.humoruniv.com/thumb.php?url_enc=uafSvgG78wf7')).toBe(
        false
      );
    });

    it('should return true for humoruniv thumb.php with plaintext url', () => {
      expect(
        isLoadableImage('https://timg.humoruniv.com/thumb.php?url=https://down.humoruniv.com/a.jpg')
      ).toBe(true);
    });

    it('should return false for .html page URL', () => {
      expect(isLoadableImage('https://example.com/page.html')).toBe(false);
    });

    it('should return false for empty string', () => {
      expect(isLoadableImage('')).toBe(false);
    });
  });

  describe('isMedia', () => {
    it('should return true for image URLs', () => {
      expect(isMedia('http://example.com/photo.jpg')).toBe(true);
    });

    it('should return true for video URLs', () => {
      expect(isMedia('http://example.com/video.mp4')).toBe(true);
    });

    it('should return true for YouTube URLs', () => {
      expect(isMedia('https://www.youtube.com/watch?v=dQw4w9WgXcQ')).toBe(true);
    });

    it('should return true for audio URLs', () => {
      expect(isMedia('http://example.com/audio.mp3')).toBe(true);
    });

    it('should return false for regular links', () => {
      expect(isMedia('https://example.com/page')).toBe(false);
    });

    it('should return false for unknown', () => {
      expect(isMedia('')).toBe(false);
    });
  });
});
