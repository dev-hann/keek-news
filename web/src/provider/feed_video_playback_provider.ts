import type { VideoId } from '../model/video_id';
import { StateNotifier, useNotifierState } from './state_notifier';

/** The one video of the feed that may be playing; null when none is. */
export class FeedVideoPlaybackNotifier extends StateNotifier<VideoId | null> {
  constructor() {
    super(null);
  }

  setActive(id: VideoId): void {
    if (this.state === id) return;
    this.state = id;
  }
}

let playback: FeedVideoPlaybackNotifier | undefined;

/** The one playback notifier of the app, made the first time a player asks for it. */
export function feedVideoPlaybackNotifier(): FeedVideoPlaybackNotifier {
  playback ??= new FeedVideoPlaybackNotifier();
  return playback;
}

/** The video that is playing, for a player that has to stop when it is another one. */
export function useActiveVideo(): VideoId | null {
  return useNotifierState(feedVideoPlaybackNotifier());
}
