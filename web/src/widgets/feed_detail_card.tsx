import type { FeedItem } from '../model/feed_item';
import type { MediaTarget } from '../model/media_target';
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
  /** Opens the comments of the post, when its body lists any. */
  onOpenComments?: () => void;
  /** Opens an image of the post full screen. */
  onOpenImage?: (index: number) => void;
  /** Opens the media action sheet for what the card shows: a long-press, or its ⋯. */
  onMore?: (target: MediaTarget) => void;
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
  onOpenComments,
  onOpenImage,
  onMore,
}: FeedDetailCardProps) {
  if (detail?.status === 'loaded') {
    return (
      <FeedCard
        post={post}
        detail={detail}
        onCopyLink={onCopyLink}
        bookmarked={bookmarked}
        onToggleBookmark={onToggleBookmark}
        onOpenComments={onOpenComments}
        onOpenImage={onOpenImage}
        onMore={onMore}
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
          onMore={onMore}
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
      onMore={onMore}
    />
  );
}
