import type { FeedItem } from '../model/feed_item';
import type { ErrorPostDetail, PostDetail } from '../model/post_detail';
import { FeedCard } from './feed_card';
import { FeedErrorCard } from './feed_error_card';

interface FeedDetailCardProps {
  post: FeedItem;
  /** The body of the post: loaded, or failed. Undefined while it has not arrived. */
  detail?: PostDetail;
  detailLoading: boolean;
  onRetry: () => void;
  onCopyLink: () => void;
  onCopyError: (error: ErrorPostDetail) => void;
}

/** A post of a list, shown by where its body stands: read, failed, or still coming. */
export function FeedDetailCard({
  post,
  detail,
  detailLoading,
  onRetry,
  onCopyLink,
  onCopyError,
}: FeedDetailCardProps) {
  if (detail?.status === 'loaded') {
    return <FeedCard post={post} detail={detail} onCopyLink={onCopyLink} />;
  }
  if (detail?.status === 'error') {
    return (
      <FeedErrorCard
        post={post}
        failure={detail.failure}
        onRetry={onRetry}
        onCopyError={() => onCopyError(detail)}
      />
    );
  }
  return <FeedCard post={post} detailLoading={detailLoading} onCopyLink={onCopyLink} />;
}
