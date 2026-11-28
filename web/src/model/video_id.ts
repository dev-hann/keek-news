import type { FeedItemKey } from './feed_item';

/** One video of one post: the post's key, then which video of it. Equal strings are the same video. */
export type VideoId = `${FeedItemKey}#${number}`;

export function videoId(postKey: FeedItemKey, blockIndex: number): VideoId {
  return `${postKey}#${blockIndex}`;
}
