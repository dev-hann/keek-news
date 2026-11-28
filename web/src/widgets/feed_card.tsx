import { Bookmark, BookmarkCheck, Link as LinkIcon } from 'lucide-react';
import { Card } from '../components/ui/card';
import { Skeleton } from '../components/ui/skeleton';
import type { VideoBlock } from '../model/content_block';
import { feedItemKey, type FeedItem } from '../model/feed_item';
import type { Failure } from '../model/failures';
import type { MediaTarget } from '../model/media_target';
import type { LoadedPostDetail } from '../model/post_detail';
import { feedBodyText } from '../utils/body_text';
import { listedCommentCount } from '../utils/listed_comment_count';
import { formatTimeAgo } from '../utils/time_ago';
import { ActionButton } from './action_button';
import { Avatar } from './avatar';
import { CardBodyError } from './card_body_error';
import { BestBadge, CommentBadge, RecommendBadge, ViewBadge } from './count_badge';
import { ExpandableText } from './expandable_text';
import { FeedImageCarousel } from './feed_image_carousel';
import { useImageLoader } from '../utils/use_image_loader';

/** What a saved post looked like in its listing, for a card whose body did not come. */
function SavedThumbnail({ src }: { src: string }) {
  const [state] = useImageLoader(src);
  return (
    <span className="flex size-12 shrink-0 items-center justify-center overflow-hidden rounded-lg bg-muted">
      {state === 'loaded' && (
        <img
          src={src}
          alt="저장할 때의 미리보기 그림"
          loading="lazy"
          decoding="async"
          referrerPolicy="no-referrer"
          className="size-full object-cover"
        />
      )}
    </span>
  );
}

/** The box that waits for the media of a post: most of a screen, never more than 600px. */
const MEDIA_BOX_HEIGHT = 'min(600px, 66vh)';

interface FeedCardProps {
  post: FeedItem;
  /** The body of the post, once it has arrived. */
  detail?: LoadedPostDetail;
  detailLoading?: boolean;
  /**
   * Why the body could not be read, shown inside the card. The card keeps
   * what the listing knows about the post: for a saved post, which must not
   * turn into an error card.
   */
  bodyError?: Failure;
  onRetry?: () => void;
  onCopyLink?: () => void;
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

/**
 * The first comment of a post under its text, with how many comments there
 * are. A button where a page can open the comments; plain text where none can.
 */
function CommentPreview({
  count,
  author,
  content,
  onOpen,
}: {
  count: number;
  author: string;
  content: string;
  onOpen?: () => void;
}) {
  const lines = (
    <>
      <p>댓글 {count}개 모두 보기</p>
      <p className="truncate">
        <span className="font-bold">{author} </span>
        {content}
      </p>
    </>
  );

  if (!onOpen) return <div className="px-4 py-2 text-sm text-muted-foreground">{lines}</div>;
  return (
    <button
      type="button"
      onClick={onOpen}
      className="block w-full px-4 py-2 text-left text-sm text-muted-foreground hover:bg-muted"
    >
      {lines}
    </button>
  );
}

/**
 * One post, read in the feed: who wrote it, its images, its counts, its title
 * and text, a first comment and when it was written.
 */
export function FeedCard({
  post,
  detail,
  detailLoading = false,
  bodyError,
  onRetry,
  onCopyLink,
  bookmarked = false,
  onToggleBookmark,
  onOpenComments,
  onOpenImage,
  onMore,
}: FeedCardProps) {
  const body = detail ? feedBodyText(detail) : null;
  const videos = detail?.contentBlocks.filter(
    (block): block is VideoBlock => block.type === 'video'
  );
  const hasMedia =
    detail !== undefined && (detail.imageUrls.length > 0 || (videos?.length ?? 0) > 0);
  const firstComment = detail?.comments[0];
  // One count names the preview and the comments it opens: what the body lists, replies included.
  // Until the body arrives, what the site's listing said.
  const commentCount = detail ? listedCommentCount(detail.comments) : post.commentCount;

  return (
    <Card className="gap-0 rounded-xl py-0">
      <div className="flex items-center gap-3 px-4 py-2">
        <Avatar />
        <span className="min-w-0 flex-1 truncate font-semibold">{post.author ?? ''}</span>
        {post.recommendCount >= 500 && <BestBadge />}
        {bodyError && post.thumbnailUrl && <SavedThumbnail src={post.thumbnailUrl} />}
      </div>

      {detailLoading && !hasMedia && (
        <Skeleton
          role="progressbar"
          aria-label="이미지 불러오는 중"
          className="w-full rounded-none"
          style={{ height: MEDIA_BOX_HEIGHT }}
        />
      )}
      {detail && (
        <FeedImageCarousel
          postKey={feedItemKey(post)}
          images={detail.imageUrls}
          videos={videos ?? []}
          onOpenImage={onOpenImage}
          onMore={onMore}
        />
      )}

      <div className="flex items-center gap-4 px-4 py-2">
        <RecommendBadge count={post.recommendCount} />
        <CommentBadge count={commentCount} />
        <ViewBadge count={post.viewCount} />
        {(onCopyLink || onToggleBookmark) && (
          <>
            <span className="flex-1" />
            {onCopyLink && <ActionButton icon={LinkIcon} label="링크 복사" onClick={onCopyLink} />}
            {onToggleBookmark && (
              <ActionButton
                icon={bookmarked ? BookmarkCheck : Bookmark}
                label={bookmarked ? '저장 취소' : '저장'}
                pressed={bookmarked}
                onClick={onToggleBookmark}
              />
            )}
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
        {bodyError && <CardBodyError failure={bodyError} onRetry={onRetry} />}
      </div>

      {detail && firstComment && (
        <CommentPreview
          count={commentCount}
          author={firstComment.author}
          content={firstComment.content}
          onOpen={onOpenComments}
        />
      )}

      {post.publishedAt && (
        <p className="px-4 pt-1 pb-2 text-sm text-muted-foreground">
          {formatTimeAgo(post.publishedAt)}
        </p>
      )}
    </Card>
  );
}
