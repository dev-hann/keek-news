import type { RefObject } from 'react';
import type { Comment } from '../model/comment';
import type { VideoBlock } from '../model/content_block';
import type { MediaTarget } from '../model/media_target';
import { listedCommentCount } from '../utils/listed_comment_count';
import { BottomSheet } from './bottom_sheet';
import { CommentTile } from './comment_tile';

interface CommentsSheetProps {
  /** The comments of a post as its body lists them, replies included. */
  comments: Comment[];
  open: boolean;
  /** The sheet asks with it to be closed: set `open` to false. */
  onClose: () => void;
  /** What gets the focus back when the sheet closes. Left out: what has it when the sheet opens. */
  returnFocusTo?: RefObject<HTMLElement | null>;
  /** Opens the pictures of a comment full screen, on the one at `index` among that comment's own images. */
  onOpenImage?: (images: string[], index: number) => void;
  /** Opens a video of a comment full screen. */
  onOpenVideo?: (video: VideoBlock) => void;
  /** Opens the media menu for a picture or a video of a comment: a long-press on it. */
  onMore?: (target: MediaTarget) => void;
}

/**
 * The comments of a post in a sheet over the feed, to read: nothing in it
 * writes. The page only sets `open` to false when `onClose` runs: system
 * Back does that too, before it can leave the page.
 *
 * The media of a comment open something only where the page says what: a
 * picture the viewer, a video the player, a long-press the media menu. A
 * viewer opened from here sits over the sheet, with its own history entry.
 */
export function CommentsSheet({
  comments,
  open,
  onClose,
  returnFocusTo,
  onOpenImage,
  onOpenVideo,
  onMore,
}: CommentsSheetProps) {
  const title = `댓글 ${listedCommentCount(comments)}개`;

  return (
    <BottomSheet
      open={open}
      onClose={onClose}
      label={title}
      title={title}
      returnFocusTo={returnFocusTo}
    >
      {comments.length === 0 ? (
        <p className="py-8 text-center text-muted-foreground">댓글이 없습니다.</p>
      ) : (
        <ul>
          {comments.map((comment) => (
            <CommentTile
              key={comment.id}
              comment={comment}
              onOpenImage={onOpenImage}
              onOpenVideo={onOpenVideo}
              onMore={onMore}
            />
          ))}
        </ul>
      )}
    </BottomSheet>
  );
}
