import { describe, expect, it } from 'vitest';
import type { Comment } from '../../src/model/comment';
import { listedCommentCount } from '../../src/utils/listed_comment_count';

const comment = (id: number, replies: Comment[] = []): Comment => ({
  id,
  author: '길동이',
  content: '',
  date: new Date(2026, 10, 1),
  recommendCount: 0,
  isBest: false,
  mediaBlocks: [],
  replies,
});

describe('listedCommentCount', () => {
  it('is 0 without a comment, which is what keeps the preview of a card from opening', () => {
    expect(listedCommentCount([])).toBe(0);
  });

  it('counts each comment once', () => {
    expect(listedCommentCount([comment(1), comment(2), comment(3)])).toBe(3);
  });

  it('counts the replies under their parent at any depth, and their parent only once', () => {
    const comments = [
      comment(1, [comment(11, [comment(111), comment(112, [comment(1121)])]), comment(12)]),
      comment(2),
    ];

    expect(listedCommentCount(comments)).toBe(7);
  });

  it('is above 0 exactly when the post has a comment', () => {
    expect(listedCommentCount([comment(1, [])]) > 0).toBe(true);
    expect(listedCommentCount([comment(1, [comment(11)])]) > 0).toBe(true);
    expect(listedCommentCount([]) > 0).toBe(false);
  });
});
