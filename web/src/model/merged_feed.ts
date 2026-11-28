import type { CommunityId } from './community';
import type { FeedItem } from './feed_item';

/** Where each community's list continues. A community without more pages maps to null. */
export interface MergedCursor {
  perSourceTokens: Partial<Record<CommunityId, string | null>>;
}

export function cursorHasMore(cursor: MergedCursor): boolean {
  return Object.values(cursor.perSourceTokens).some((token) => token != null);
}

export interface MergedPage {
  items: FeedItem[];
  next: MergedCursor | null;
  /** The communities that failed to answer; the page holds the others. */
  failedSources: Set<CommunityId>;
}
