import { communityIds, type CommunityId } from './community';
import type { FeedItem, FeedItemKey } from './feed_item';

/** A post the user saved: what the feed listed about it, and when it was saved. */
export interface Bookmark {
  community: CommunityId;
  id: string;
  title: string;
  url: string;
  savedAt: Date;
  author?: string;
  thumbnailUrl?: string;
  publishedAt?: Date;
  recommendCount: number;
  commentCount: number;
  viewCount: number;
}

/**
 * A bookmark as stored: one entry of the JSON list under `bookmarks`. It is the
 * shape the Flutter app wrote, and a later slice moves that data over unchanged.
 * A type rather than an interface: `assertStoredBookmark` needs it to stand for
 * a record.
 */
export type BookmarkJson = {
  community: CommunityId;
  id: string;
  title: string;
  url: string;
  savedAtMillis: number;
  author?: string;
  thumbnailUrl?: string;
  publishedAtMillis?: number;
  recommendCount: number;
  commentCount: number;
  viewCount: number;
};

/** The key of a bookmark, the same one its post has as a feed item. */
export const bookmarkKey = (bookmark: Bookmark): FeedItemKey =>
  `${bookmark.community}:${bookmark.id}`;

export function bookmarkFromFeedItem(item: FeedItem, savedAt: Date): Bookmark {
  return {
    community: item.community,
    id: item.id,
    title: item.title,
    url: item.url,
    savedAt,
    ...(item.author == null ? {} : { author: item.author }),
    ...(item.thumbnailUrl == null ? {} : { thumbnailUrl: item.thumbnailUrl }),
    ...(item.publishedAt == null ? {} : { publishedAt: item.publishedAt }),
    recommendCount: item.recommendCount,
    commentCount: item.commentCount,
    viewCount: item.viewCount,
  };
}

const isCommunityId = (value: unknown): value is CommunityId =>
  typeof value === 'string' && (communityIds as readonly string[]).includes(value);

const isText = (value: unknown): boolean => typeof value === 'string';

const isCount = (value: unknown): boolean => typeof value === 'number';

/** Whole milliseconds since the epoch: Dart's DateTime and the web's Date stop at the same ±100,000,000 days. */
const isMillis = (value: unknown): boolean =>
  typeof value === 'number' && Number.isInteger(value) && Math.abs(value) <= 8.64e15;

/** The Flutter app left out what it lacked, or wrote null: either reads as absent. */
const isOptional = (value: unknown, is: (value: unknown) => boolean): boolean =>
  value === null || value === undefined || is(value);

/**
 * Throws unless `json` is a stored bookmark. The Flutter app read one with
 * casts; the repository skips an entry they reject, so this throws instead.
 */
function assertStoredBookmark(json: Record<string, unknown>): asserts json is BookmarkJson {
  const stored =
    isCommunityId(json.community) &&
    isText(json.id) &&
    isText(json.title) &&
    isText(json.url) &&
    isMillis(json.savedAtMillis) &&
    isOptional(json.author, isText) &&
    isOptional(json.thumbnailUrl, isText) &&
    isOptional(json.publishedAtMillis, isMillis) &&
    isOptional(json.recommendCount, isCount) &&
    isOptional(json.commentCount, isCount) &&
    isOptional(json.viewCount, isCount);
  if (!stored) throw new TypeError('Not a stored bookmark');
}

/** Reads a stored bookmark. Throws when `json` is not one, as the Flutter app's casts did. */
export function bookmarkFromJson(json: Record<string, unknown>): Bookmark {
  assertStoredBookmark(json);
  return {
    community: json.community,
    id: json.id,
    title: json.title,
    url: json.url,
    savedAt: new Date(json.savedAtMillis),
    ...(json.author == null ? {} : { author: json.author }),
    ...(json.thumbnailUrl == null ? {} : { thumbnailUrl: json.thumbnailUrl }),
    ...(json.publishedAtMillis == null ? {} : { publishedAt: new Date(json.publishedAtMillis) }),
    // A count missing from what was stored reads as 0; a fraction is cut off.
    recommendCount: Math.trunc(json.recommendCount ?? 0),
    commentCount: Math.trunc(json.commentCount ?? 0),
    viewCount: Math.trunc(json.viewCount ?? 0),
  };
}

export function bookmarkToJson(bookmark: Bookmark): BookmarkJson {
  return {
    community: bookmark.community,
    id: bookmark.id,
    title: bookmark.title,
    url: bookmark.url,
    savedAtMillis: bookmark.savedAt.getTime(),
    ...(bookmark.author == null ? {} : { author: bookmark.author }),
    ...(bookmark.thumbnailUrl == null ? {} : { thumbnailUrl: bookmark.thumbnailUrl }),
    ...(bookmark.publishedAt == null ? {} : { publishedAtMillis: bookmark.publishedAt.getTime() }),
    recommendCount: bookmark.recommendCount,
    commentCount: bookmark.commentCount,
    viewCount: bookmark.viewCount,
  };
}
