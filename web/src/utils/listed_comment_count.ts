import type { Comment } from '../model/comment';

/**
 * How many comments the sheet of a post lists: each comment and, under it,
 * each reply at any depth, once. It names the sheet and the preview of the
 * card that opens it, and that preview is tappable iff the number is not 0.
 *
 * Not the total the site shows for the post.
 */
export function listedCommentCount(comments: Comment[]): number {
  return comments.reduce((count, comment) => count + 1 + listedCommentCount(comment.replies), 0);
}
