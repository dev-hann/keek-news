import { Play, ThumbsUp } from 'lucide-react';
import { cn } from 'cn';
import { commentImageUrls, type Comment } from '../model/comment';
import type { VideoBlock } from '../model/content_block';
import { imageTarget, videoTarget, type MediaTarget } from '../model/media_target';
import { formatTimeAgo } from '../utils/time_ago';
import { useLongPress } from '../utils/use_long_press';
import { BestBadge } from './count_badge';
import { LinkText } from './link_text';

interface CommentTileProps {
  comment: Comment;
  /** 0 for a comment on the post, 1 for a reply to it, 2 for a reply to a reply. */
  depth?: number;
  /** Opens the pictures of this comment full screen, on the one at `index` among the comment's own images. */
  onOpenImage?: (images: string[], index: number) => void;
  /** Opens a video of this comment full screen. */
  onOpenVideo?: (video: VideoBlock) => void;
  /** Opens the media menu for a picture or a video of this comment: a long-press on it. */
  onMore?: (target: MediaTarget) => void;
}

/** What a comment shows of one of its media: an image as it is, a video by its poster. */
type Medium =
  | { kind: 'image'; key: string; url: string; index: number }
  | { kind: 'video'; key: string; block: VideoBlock; poster: string | null };

/**
 * The media of a comment, in the order it carries them. A video without a
 * poster is one only where a tap can play it: there is nothing of it to show.
 */
function mediaOf(comment: Comment, canPlay: boolean): Medium[] {
  let imageIndex = 0;
  return comment.mediaBlocks.flatMap((block, at): Medium[] => {
    // A comment can hold the same address twice: the key is where the block is, not what it is.
    if (block.type === 'image') {
      return [{ kind: 'image', key: `${at}`, url: block.url, index: imageIndex++ }];
    }
    if (block.type === 'video' && (canPlay || block.thumbnailUrl !== undefined)) {
      return [{ kind: 'video', key: `${at}`, block, poster: block.thumbnailUrl ?? null }];
    }
    return [];
  });
}

/** The 72px tier of a thumbnail, by height: at least 72 wide, never wider than the row. */
const PICTURE = 'h-18 w-auto min-w-18 max-w-full rounded-lg bg-muted object-cover';

/** A thumbnail that opens something: its picture fills it, and the ring shows inside its corner. */
const TAP =
  'relative block h-18 max-w-full overflow-hidden rounded-lg outline-none focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:ring-inset';

/** Says that a tap plays: over the poster, or in the box of a video that has none. */
const PLAY =
  'absolute inset-0 m-auto flex size-8 items-center justify-center rounded-full bg-background/80 text-primary';

interface ThumbProps {
  medium: Medium;
  /** Who wrote the comment: the name of a picture says whose it is. */
  author: string;
  /** The images of the comment, in order: what the viewer opens on. */
  images: string[];
  onOpenImage?: (images: string[], index: number) => void;
  onOpenVideo?: (video: VideoBlock) => void;
  onMore?: (target: MediaTarget) => void;
}

/**
 * A picture or a video of a comment, the height of a thumbnail. Where the
 * page says what a tap opens, it is a button; where it says what a long-press
 * opens, it is pressed long. Where it says neither, it is a plain picture.
 */
function Thumb({ medium, author, images, onOpenImage, onOpenVideo, onMore }: ThumbProps) {
  const image = medium.kind === 'image';
  const src = image ? medium.url : medium.poster;
  const target = image ? imageTarget(medium.url) : videoTarget(medium.block);
  // A plain picture says whose it is; the button over one says too which of the comment's it is.
  const alt = image ? `${author}의 댓글 이미지` : `${author}의 댓글 동영상`;
  const name = image ? `${alt} ${medium.index + 1}` : alt;
  const open = image
    ? onOpenImage === undefined
      ? undefined
      : () => onOpenImage(images, medium.index)
    : onOpenVideo === undefined
      ? undefined
      : () => onOpenVideo(medium.block);
  const press = useLongPress<HTMLElement>(onMore === undefined ? undefined : () => onMore(target));

  if (open === undefined) {
    // Only a video with a poster is listed where nothing opens it, see `mediaOf`.
    if (src === null) return null;
    return (
      <img
        {...press}
        src={src}
        alt={alt}
        loading="lazy"
        decoding="async"
        referrerPolicy="no-referrer"
        className={PICTURE}
      />
    );
  }

  return (
    <button
      {...press}
      type="button"
      aria-label={name}
      onClick={open}
      className={cn(TAP, src === null && 'w-18 bg-muted')}
    >
      {/* Where a tap opens the picture, the button is what is named: the picture itself is not. */}
      {src !== null && (
        <img
          src={src}
          alt=""
          loading="lazy"
          decoding="async"
          referrerPolicy="no-referrer"
          className={PICTURE}
        />
      )}
      {medium.kind === 'video' && (
        <span className={PLAY}>
          <Play aria-hidden="true" className="size-5 translate-x-0.5" />
        </span>
      )}
    </button>
  );
}

/**
 * One comment of a post as the sheet lists it: who wrote it and when, how
 * many recommended it, what it says and shows, and under it its replies.
 * Nothing in it acts but its media, and only where the page says what they
 * open. The replies' media are the comment's.
 */
export function CommentTile({
  comment,
  depth = 0,
  onOpenImage,
  onOpenVideo,
  onMore,
}: CommentTileProps) {
  const reply = depth > 0;
  const media = mediaOf(comment, onOpenVideo !== undefined);
  const images = commentImageUrls(comment);

  return (
    <li
      className={cn(
        'py-2',
        reply &&
          'relative pl-4 before:absolute before:inset-y-0 before:left-1 before:w-px before:bg-border'
      )}
    >
      <div className="flex flex-wrap items-center gap-x-2 gap-y-1 text-sm text-muted-foreground">
        <span className="font-bold text-foreground">{comment.author}</span>
        {comment.isBest && <BestBadge />}
        <span>{formatTimeAgo(comment.date)}</span>
        {/* The icon alone would say nothing to a screen reader. */}
        <span className="inline-flex items-center gap-1 tabular-nums">
          <span className="sr-only">추천 </span>
          <ThumbsUp aria-hidden="true" className="size-4" />
          <span>{comment.recommendCount}</span>
        </span>
      </div>
      {comment.content !== '' && (
        <p
          className={cn(
            'mt-1 break-words whitespace-pre-line',
            reply ? 'text-sm text-muted-foreground' : 'text-base'
          )}
        >
          <LinkText text={comment.content} />
        </p>
      )}
      {media.length > 0 && (
        // The WebView's own menu for a long press on a picture: the sheet of the app is what opens.
        <div
          className="mt-2 flex flex-wrap gap-2 select-none [-webkit-touch-callout:none]"
          onContextMenu={(event) => event.preventDefault()}
        >
          {media.map((medium) => (
            <Thumb
              key={medium.key}
              medium={medium}
              author={comment.author}
              images={images}
              onOpenImage={onOpenImage}
              onOpenVideo={onOpenVideo}
              onMore={onMore}
            />
          ))}
        </div>
      )}
      {comment.replies.length > 0 && (
        <ul className="mt-2">
          {comment.replies.map((child) => (
            <CommentTile
              key={child.id}
              comment={child}
              depth={depth + 1}
              onOpenImage={onOpenImage}
              onOpenVideo={onOpenVideo}
              onMore={onMore}
            />
          ))}
        </ul>
      )}
    </li>
  );
}
