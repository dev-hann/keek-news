import { describe, expect, it } from 'vitest';
import type { VideoBlock } from '../../src/model/content_block';
import { imageTarget, isDownloadable, videoTarget } from '../../src/model/media_target';

const video = (url: string, extra: Partial<VideoBlock> = {}): VideoBlock => ({
  type: 'video',
  url,
  ...extra,
});

describe('imageTarget', () => {
  it('marks any image url as image kind', () => {
    const target = imageTarget('https://example.com/a.jpg');

    expect(target.kind).toBe('image');
    expect(isDownloadable(target)).toBe(true);
  });
});

describe('videoTarget', () => {
  it('marks a direct video url as video kind', () => {
    const target = videoTarget(video('https://example.com/clip.mp4'));

    expect(target.kind).toBe('video');
    expect(isDownloadable(target)).toBe(true);
  });

  it('marks a youtube watch url as external embed', () => {
    const target = videoTarget(video('https://www.youtube.com/watch?v=abc12345678'));

    expect(target.kind).toBe('external');
    expect(isDownloadable(target)).toBe(false);
  });

  it('marks a short youtu.be url as external embed', () => {
    expect(videoTarget(video('https://youtu.be/abc12345678')).kind).toBe('external');
  });

  it('marks a vimeo url as external embed', () => {
    expect(videoTarget(video('https://vimeo.com/123456')).kind).toBe('external');
  });

  it('does not take a look-alike host for an embed host', () => {
    expect(videoTarget(video('https://notyoutube.com/clip.mp4')).kind).toBe('video');
  });

  it('gif-converted clips stay video kind', () => {
    const target = videoTarget(video('https://example.com/gif.mp4', { isGifConversion: true }));

    expect(target.kind).toBe('video');
    expect(isDownloadable(target)).toBe(true);
  });
});

describe('equality', () => {
  it('same url and kind are equal', () => {
    expect(imageTarget('https://a/1.jpg')).toEqual(imageTarget('https://a/1.jpg'));
  });

  it('different kinds are not equal', () => {
    expect(imageTarget('https://youtu.be/abc12345678')).not.toEqual(
      videoTarget(video('https://youtu.be/abc12345678'))
    );
  });
});
