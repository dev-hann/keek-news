import type { RefObject } from 'react';
import type { Comment } from '../model/comment';
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
}

/**
 * The comments of a post in a sheet over the feed, to read only. The page
 * only sets `open` to false when `onClose` runs: system Back does that too
 * before it can leave the page.
 */
export function CommentsSheet({ comments, open, onClose, returnFocusTo }: CommentsSheetProps) {
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
            <CommentTile key={comment.id} comment={comment} />
          ))}
        </ul>
      )}
    </BottomSheet>
  );
}
