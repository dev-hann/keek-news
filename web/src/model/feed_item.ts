import type { CommunityId } from './community';

/** One post of a feed list. The body is not part of it: it is fetched per post. */
export interface FeedItem {
  community: CommunityId;
  id: string;
  title: string;
  /** Path of the post on its community, as the site links to it. */
  url: string;
  author?: string;
  publishedAt?: Date;
  recommendCount: number;
  commentCount: number;
  viewCount: number;
  thumbnailUrl?: string;
}

export type FeedItemKey = `${CommunityId}:${string}`;

export const feedItemKey = (item: FeedItem): FeedItemKey => `${item.community}:${item.id}`;

export function parseFeedItemKey(key: FeedItemKey): { community: CommunityId; id: string } {
  const separator = key.indexOf(':');
  return { community: key.slice(0, separator) as CommunityId, id: key.slice(separator + 1) };
}
