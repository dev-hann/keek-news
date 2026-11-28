import type { Comment } from '../model/comment';
import type { ContentBlock } from '../model/content_block';
import type { PostDetail } from '../model/post_detail';

const isBlockedImage = (block: ContentBlock, blocked: Set<string>): boolean =>
  block.type === 'image' && blocked.has(block.url);

function filterComment(comment: Comment, blocked: Set<string>): Comment {
  const mediaBlocks = comment.mediaBlocks.filter((b) => !isBlockedImage(b, blocked));
  const replies = comment.replies.map((r) => filterComment(r, blocked));
  return { ...comment, replies, mediaBlocks };
}

/**
 * Removes images whose canonical URL is in `blocked` from a post detail
 * (body blocks, detail imageUrls, and comment media recursively).
 * Non-loaded detail states pass through untouched; an empty blocklist
 * returns `detail` as-is.
 */
export function filterBlockedPostDetail(
  detail: PostDetail | null,
  blocked: Set<string>
): PostDetail | null {
  if (detail === null || detail.status !== 'loaded' || blocked.size === 0) return detail;

  const contentBlocks = detail.contentBlocks.filter((b) => !isBlockedImage(b, blocked));
  const imageUrls = detail.imageUrls.filter((url) => !blocked.has(url));
  const comments = detail.comments.map((c) => filterComment(c, blocked));

  return { ...detail, contentBlocks, imageUrls, comments };
}
