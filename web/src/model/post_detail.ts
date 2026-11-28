import type { CommunityId } from './community';
import type { Comment } from './comment';
import type { ContentBlock } from './content_block';
import type { Failure } from './failures';

export type PostDetail = LoadedPostDetail | ErrorPostDetail;

interface PostDetailBase {
  id: number;
  community: CommunityId;
}

export interface LoadedPostDetail extends PostDetailBase {
  status: 'loaded';
  title: string;
  author: string;
  date: Date;
  contentBlocks: ContentBlock[];
  imageUrls: string[];
  recommendCount: number;
  notRecommendCount: number;
  viewCount: number;
  commentCount: number;
  comments: Comment[];
}

export interface ErrorPostDetail extends PostDetailBase {
  status: 'error';
  failure: Failure;
}

/**
 * True when the page returned no parseable body, images or comments: almost
 * always a block or an interstitial (HTTP 200 with challenge HTML), not an
 * empty post.
 */
export function looksEmpty(detail: LoadedPostDetail): boolean {
  return (
    detail.contentBlocks.length === 0 &&
    detail.imageUrls.length === 0 &&
    detail.comments.length === 0
  );
}
