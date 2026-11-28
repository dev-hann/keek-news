import { ThumbsUp } from 'lucide-react';
import { cn } from 'cn';
import type { Comment } from '../model/comment';
import { formatTimeAgo } from '../utils/time_ago';
import { BestBadge } from './count_badge';
import { LinkText } from './link_text';

interface CommentTileProps {
  comment: Comment;
  /** 0 for a comment on the post, 1 for a reply to it, 2 for a reply to a reply. */
  depth?: number;
}

/** What a comment shows of its media: an image as it is, a video by its poster. */
function thumbnails(comment: Comment): { url: string; alt: string }[] {
  return comment.mediaBlocks.flatMap((block) => {
    if (block.type === 'image') {
      return [{ url: block.url, alt: `${comment.author}의 댓글 이미지` }];
    }
    if (block.type === 'video' && block.thumbnailUrl) {
      return [{ url: block.thumbnailUrl, alt: `${comment.author}의 댓글 동영상` }];
    }
    return [];
  });
}

/**
 * One comment of a post as the sheet lists it: who wrote it and when, how
 * many recommended it, what it says and shows, and under it its replies.
 * Nothing in it acts: it is read only.
 */
export function CommentTile({ comment, depth = 0 }: CommentTileProps) {
  const reply = depth > 0;
  const media = thumbnails(comment);

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
        <div className="mt-2 flex flex-wrap gap-2">
          {media.map((thumbnail, index) => (
            <img
              key={`${thumbnail.url}#${index}`}
              src={thumbnail.url}
              alt={thumbnail.alt}
              loading="lazy"
              decoding="async"
              referrerPolicy="no-referrer"
              className="h-18 w-auto min-w-18 max-w-full rounded-lg bg-muted object-cover"
            />
          ))}
        </div>
      )}
      {comment.replies.length > 0 && (
        <ul className="mt-2">
          {comment.replies.map((child) => (
            <CommentTile key={child.id} comment={child} depth={depth + 1} />
          ))}
        </ul>
      )}
    </li>
  );
}
