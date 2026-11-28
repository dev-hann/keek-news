import { describe, expect, it, vi } from 'vitest';
import { videoId, type VideoId } from '../../src/model/video_id';
import { FeedVideoPlaybackNotifier } from '../../src/provider/feed_video_playback_provider';

const id = (postId: number, blockIndex: number): VideoId =>
  videoId(`humoruniv:${postId}`, blockIndex);

describe('FeedVideoPlaybackNotifier', () => {
  it('initial activeVideoId is null', () => {
    expect(new FeedVideoPlaybackNotifier().getState()).toBeNull();
  });

  it('setActive stores the given VideoId', () => {
    const notifier = new FeedVideoPlaybackNotifier();

    notifier.setActive(id(1, 0));

    expect(notifier.getState()).toEqual(id(1, 0));
  });

  it('setActive replaces the previous VideoId (single-slot)', () => {
    const notifier = new FeedVideoPlaybackNotifier();

    notifier.setActive(id(1, 0));
    notifier.setActive(id(2, 0));

    expect(notifier.getState()).toEqual(id(2, 0));
  });

  it('different post/block produce different VideoIds', () => {
    expect(id(1, 0)).not.toBe(id(1, 1));
    expect(id(1, 0)).not.toBe(id(2, 0));
  });

  it('tells its listeners only when the video changes', () => {
    const notifier = new FeedVideoPlaybackNotifier();
    const listener = vi.fn();
    notifier.subscribe(listener);

    notifier.setActive(id(1, 0));
    notifier.setActive(id(1, 0));
    notifier.setActive(id(2, 0));

    expect(listener).toHaveBeenCalledTimes(2);
  });
});
