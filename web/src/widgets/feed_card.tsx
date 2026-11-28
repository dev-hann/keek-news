import { Link as LinkIcon } from 'lucide-react';
import { Card } from '../components/ui/card';
import { Skeleton } from '../components/ui/skeleton';
import type { FeedItem } from '../model/feed_item';
import type { LoadedPostDetail } from '../model/post_detail';
import { feedBodyText } from '../utils/body_text';
import { formatTimeAgo } from '../utils/time_ago';
import { ActionButton } from './action_button';
import { Avatar } from './avatar';
import { BestBadge, CommentBadge, RecommendBadge, ViewBadge } from './count_badge';
import { ExpandableText } from './expandable_text';
import { FeedMedia } from './feed_media';

/** The box that waits for the media of a post: most of a screen, never more than 600px. */
const MEDIA_BOX_HEIGHT = 'min(600px, 66vh)';

interface FeedCardProps {
  post: FeedItem;
  /** The body of the post, once it has arrived. */
  detail?: LoadedPostDetail;
  detailLoading?: boolean;
  onCopyLink?: () => void;
}

/**
 * One post, read in the feed: who wrote it, its images, its counts, its title
 * and text, a first comment and when it was written.
 */
export function FeedCard({ post, detail, detailLoading = false, onCopyLink }: FeedCardProps) {
  const body = detail ? feedBodyText(detail) : null;
  const hasMedia =
    detail !== undefined &&
    (detail.imageUrls.length > 0 || detail.contentBlocks.some((block) => block.type === 'video'));
  const firstComment = detail?.comments[0];

  return (
    <Card className="gap-0 rounded-xl py-0">
      <div className="flex items-center gap-3 px-4 py-2">
        <Avatar />
        <span className="min-w-0 flex-1 truncate font-semibold">{post.author ?? ''}</span>
        {post.recommendCount >= 500 && <BestBadge />}
      </div>

      {detailLoading && !hasMedia && (
        <Skeleton
          role="progressbar"
          aria-label="이미지 불러오는 중"
          className="w-full rounded-none"
          style={{ height: MEDIA_BOX_HEIGHT }}
        />
      )}
      {detail && <FeedMedia detail={detail} />}

      <div className="flex items-center gap-4 px-4 py-2">
        <RecommendBadge count={post.recommendCount} />
        <CommentBadge
          count={post.commentCount !== 0 ? post.commentCount : (detail?.commentCount ?? 0)}
        />
        <ViewBadge count={post.viewCount} />
        {onCopyLink && (
          <>
            <span className="flex-1" />
            <ActionButton icon={LinkIcon} label="링크 복사" onClick={onCopyLink} />
          </>
        )}
      </div>

      <div className="px-4 pb-2">
        <h2 className="line-clamp-2 text-base leading-snug font-semibold">{post.title}</h2>
        {body && (
          <ExpandableText
            text={body}
            maxLines={hasMedia ? 3 : 8}
            className="pt-1 text-sm break-words whitespace-pre-line text-muted-foreground"
          />
        )}
      </div>

      {detail && firstComment && (
        <div className="px-4 py-2 text-sm text-muted-foreground">
          <p>댓글 {detail.commentCount}개 모두 보기</p>
          <p className="truncate">
            <span className="font-bold">{firstComment.author} </span>
            {firstComment.content}
          </p>
        </div>
      )}

      {post.publishedAt && (
        <p className="px-4 pt-1 pb-2 text-sm text-muted-foreground">
          {formatTimeAgo(post.publishedAt)}
        </p>
      )}
    </Card>
  );
}
