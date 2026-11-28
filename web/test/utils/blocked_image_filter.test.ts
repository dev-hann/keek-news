import { describe, expect, it } from 'vitest';
import { commentImageUrls, type Comment } from '../../src/model/comment';
import type { ContentBlock } from '../../src/model/content_block';
import { ServerFailure } from '../../src/model/failures';
import type { LoadedPostDetail, PostDetail } from '../../src/model/post_detail';
import { filterBlockedPostDetail } from '../../src/utils/blocked_image_filter';

/** The one element of a list, as Dart's `.single`. */
const single = <T>(items: T[]): T => {
  expect(items).toHaveLength(1);
  return items[0];
};

/** Dart's `as LoadedPostDetail`: fails unless the detail came back loaded. */
const asLoaded = (detail: PostDetail | null): LoadedPostDetail => {
  if (detail === null || detail.status !== 'loaded') throw new Error('not a loaded detail');
  return detail;
};

function _detail({
  blocks = [],
  imageUrls = [],
  comments = [],
}: {
  blocks?: ContentBlock[];
  imageUrls?: string[];
  comments?: Comment[];
} = {}): LoadedPostDetail {
  return {
    status: 'loaded',
    id: 1,
    community: 'humoruniv',
    title: 'title',
    author: 'author',
    date: new Date(0),
    contentBlocks: blocks,
    imageUrls: imageUrls,
    recommendCount: 0,
    notRecommendCount: 0,
    viewCount: 0,
    commentCount: comments.length,
    comments: comments,
  };
}

function _comment({
  id = 1,
  mediaBlocks = [],
  replies = [],
}: {
  id?: number;
  mediaBlocks?: ContentBlock[];
  replies?: Comment[];
} = {}): Comment {
  return {
    id,
    author: 'a',
    content: 'c',
    date: new Date(0),
    recommendCount: 0,
    isBest: false,
    replies: replies,
    mediaBlocks: mediaBlocks,
  };
}

describe('filterBlockedPostDetail', () => {
  it('should return null detail untouched', () => {
    expect(filterBlockedPostDetail(null, new Set(['https://x/a.jpg']))).toBeNull();
  });

  it('should return error detail untouched', () => {
    const detail = {
      status: 'error',
      id: 1,
      community: 'humoruniv',
      failure: new ServerFailure('x'),
    } as const;

    expect(filterBlockedPostDetail(detail, new Set(['https://x/a.jpg']))).toBe(detail);
  });

  it('should return the same instance when blocklist empty', () => {
    const detail = _detail({ imageUrls: ['https://x/a.jpg'] });

    expect(filterBlockedPostDetail(detail, new Set())).toBe(detail);
  });

  it('should drop blocked body image blocks and imageUrls', () => {
    const detail = _detail({
      blocks: [
        { type: 'text', text: 'hello' },
        { type: 'image', url: 'https://x/blocked.jpg' },
        { type: 'image', url: 'https://x/keep.jpg' },
      ],
      imageUrls: ['https://x/blocked.jpg', 'https://x/keep.jpg'],
    });

    const filtered = asLoaded(filterBlockedPostDetail(detail, new Set(['https://x/blocked.jpg'])));

    expect(filtered.contentBlocks).toEqual([
      { type: 'text', text: 'hello' },
      { type: 'image', url: 'https://x/keep.jpg' },
    ]);
    expect(filtered.imageUrls).toEqual(['https://x/keep.jpg']);
  });

  it('should keep video blocks untouched', () => {
    const video: ContentBlock = { type: 'video', url: 'https://x/v.mp4' };
    const detail = _detail({ blocks: [video] });

    const filtered = asLoaded(filterBlockedPostDetail(detail, new Set(['https://x/v.mp4'])));

    expect(filtered.contentBlocks).toEqual([video]);
  });

  it('should drop blocked comment images recursively', () => {
    const detail = _detail({
      comments: [
        _comment({
          mediaBlocks: [
            { type: 'image', url: 'https://x/blocked.jpg' },
            { type: 'image', url: 'https://x/keep.jpg' },
          ],
          replies: [
            _comment({ id: 2, mediaBlocks: [{ type: 'image', url: 'https://x/blocked.jpg' }] }),
          ],
        }),
      ],
    });

    const filtered = asLoaded(filterBlockedPostDetail(detail, new Set(['https://x/blocked.jpg'])));

    const comment = single(filtered.comments);
    expect(commentImageUrls(comment)).toEqual(['https://x/keep.jpg']);
    expect(commentImageUrls(single(comment.replies))).toEqual([]);
  });

  it('should keep non-media comment fields intact', () => {
    const detail = _detail({
      comments: [
        _comment({ id: 7, mediaBlocks: [{ type: 'image', url: 'https://x/blocked.jpg' }] }),
      ],
    });

    const filtered = asLoaded(filterBlockedPostDetail(detail, new Set(['https://x/blocked.jpg'])));

    const comment = single(filtered.comments);
    expect(comment.id).toBe(7);
    expect(comment.content).toBe('c');
    expect(comment.recommendCount).toBe(0);
  });
});
