import type { FeedItemKey } from './feed_item';

/**
 * One video of one post: the post's key, then which video of it, or `-1` for the
 * video of the viewer that a comment's video opens in. Equal strings are the
 * same video.
 */
export type VideoId = `${FeedItemKey}#${number}`;

export function videoId(postKey: FeedItemKey, blockIndex: number): VideoId {
  return `${postKey}#${blockIndex}`;
}

/**
 * The video of the viewer that a comment's video opens in. One such viewer
 * is open at a time, so it has one id; `-1` is no card's block, and so never
 * the id of a video that plays under it.
 */
export function commentVideoId(postKey: FeedItemKey): VideoId {
  return videoId(postKey, -1);
}
