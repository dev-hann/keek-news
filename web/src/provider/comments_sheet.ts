import { useCallback, useState } from 'react';
import type { Comment } from '../model/comment';
import type { FeedItemKey } from '../model/feed_item';
import { filterBlockedPostDetail } from '../utils/blocked_image_filter';
import type { MergedDetailMap } from './merged_feed_provider';

/**
 * The comments sheet of a page that lists posts: which post's comments are
 * open, and what the sheet shows for it. The feed and the bookmarks list
 * each have one.
 */
export function useCommentsSheet(details: MergedDetailMap, blockedUrls: Set<string>) {
  const [commentsOf, setCommentsOf] = useState<FeedItemKey | null>(null);

  // The sheet opens only from a body that is here. One that left meanwhile, in a reload, leaves an empty sheet.
  const entry = commentsOf === null ? undefined : details.get(commentsOf);
  const detail =
    entry?.status === 'loaded' ? filterBlockedPostDetail(entry.detail, blockedUrls) : null;
  const comments: Comment[] = detail?.status === 'loaded' ? detail.comments : [];

  const open = useCallback((key: FeedItemKey) => setCommentsOf(key), []);
  const close = useCallback(() => setCommentsOf(null), []);

  return { open, close, comments, isOpen: commentsOf !== null };
}
