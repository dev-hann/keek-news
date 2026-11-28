import { describe, expect, it } from 'vitest';
import { commentVideoId, videoId } from '../../src/model/video_id';

describe('video ids', () => {
  it('names a card video by its post and its block', () => {
    expect(videoId('humoruniv:7', 2)).toBe('humoruniv:7#2');
  });

  it("names a comment's video so that it is never a card's", () => {
    // One viewer is open at a time, and -1 is no block: a video playing in a card under it gives way, and is not taken for it.
    expect(commentVideoId('humoruniv:7')).not.toBe(videoId('humoruniv:7', 0));
    expect(commentVideoId('humoruniv:7')).not.toBe(videoId('humoruniv:7', 1));
    expect(commentVideoId('humoruniv:7')).toBe(commentVideoId('humoruniv:7'));
  });
});
