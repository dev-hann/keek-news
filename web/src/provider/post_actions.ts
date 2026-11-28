import { toast } from 'sonner';
import { bookmarkFromFeedItem } from '../model/bookmark';
import { findCommunity } from '../model/community';
import type { FeedItem } from '../model/feed_item';
import type { ErrorPostDetail } from '../model/post_detail';
import { resolveAbsolute } from '../model/url_builder';
import { copyText } from '../utils/clipboard';
import { formatErrorReport } from '../utils/error_report';
import { bookmarkNotifier } from './bookmark_provider';

/** Copies the address of the post, and says whether it did. */
export async function copyPostLink(post: FeedItem): Promise<void> {
  const copied = await copyText(resolveAbsolute(post.community, post.url));
  if (copied) toast.success('링크를 복사했어요');
  else toast.error('링크를 복사하지 못했습니다');
}

/** Copies what the app could see about why the body of the post failed, for a report. */
export async function copyPostError(post: FeedItem, error: ErrorPostDetail): Promise<void> {
  const report = formatErrorReport({
    communityLabel: findCommunity(post.community)?.displayName ?? post.community,
    postId: post.id,
    url: resolveAbsolute(post.community, post.url),
    title: post.title,
    failure: error.failure,
    appVersion: __APP_VERSION__,
  });
  const copied = await copyText(report);
  if (copied) toast.success('오류 정보를 복사했어요');
  else toast.error('오류 정보를 복사하지 못했습니다');
}

/**
 * Saves the post, or unsaves it when it is saved. The icon alone cannot say
 * that nothing happened, so a write that failed is said out loud.
 */
export async function toggleBookmark(post: FeedItem): Promise<void> {
  const bookmarks = bookmarkNotifier();
  const wasSaved = bookmarks.isBookmarked(post.community, post.id);
  const saved = await bookmarks.toggle(bookmarkFromFeedItem(post, new Date()));
  if (saved === wasSaved) toast.error(saved ? '저장을 취소하지 못했어요' : '저장하지 못했어요');
}
