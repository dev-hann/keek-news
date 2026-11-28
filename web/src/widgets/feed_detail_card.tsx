import type { FeedItem } from '../model/feed_item';
import type { ErrorPostDetail, PostDetail } from '../model/post_detail';
import { FeedCard } from './feed_card';
import { FeedErrorCard } from './feed_error_card';

interface FeedDetailCardProps {
  post: FeedItem;
  /** The body of the post: loaded, or failed. Undefined while it has not arrived. */
  detail?: PostDetail;
  detailLoading: boolean;
  /**
   * A body that failed stays inside the card, under what the listing knows
   * about the post. For saved posts: their card must not go.
   */
  keepOnBodyError?: boolean;
  onRetry: () => void;
  onCopyLink: () => void;
  onCopyError: (error: ErrorPostDetail) => void;
  /** Whether the post is saved, and what saves or unsaves it. */
  bookmarked?: boolean;
  onToggleBookmark?: () => void;
}

/** A post of a list, shown by where its body stands: read, failed, or still coming. */
export function FeedDetailCard({
  post,
  detail,
  detailLoading,
  keepOnBodyError = false,
  onRetry,
  onCopyLink,
  onCopyError,
  bookmarked,
  onToggleBookmark,
}: FeedDetailCardProps) {
  if (detail?.status === 'loaded') {
    return (
      <FeedCard
        post={post}
        detail={detail}
        onCopyLink={onCopyLink}
        bookmarked={bookmarked}
        onToggleBookmark={onToggleBookmark}
      />
    );
  }
  if (detail?.status === 'error') {
    if (keepOnBodyError) {
      return (
        <FeedCard
          post={post}
          bodyError={detail.failure}
          onRetry={onRetry}
          onCopyLink={onCopyLink}
          bookmarked={bookmarked}
          onToggleBookmark={onToggleBookmark}
        />
      );
    }
    return (
      <FeedErrorCard
        post={post}
        failure={detail.failure}
        onRetry={onRetry}
        onCopyError={() => onCopyError(detail)}
      />
    );
  }
  return (
    <FeedCard
      post={post}
      detailLoading={detailLoading}
      onCopyLink={onCopyLink}
      bookmarked={bookmarked}
      onToggleBookmark={onToggleBookmark}
    />
  );
}
