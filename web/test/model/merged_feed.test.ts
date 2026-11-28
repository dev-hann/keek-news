import { describe, expect, it } from 'vitest';
import type { FeedItem } from '../../src/model/feed_item';
import { cursorHasMore, type MergedCursor } from '../../src/model/merged_feed';

describe('MergedCursor', () => {
  it('holds the page token of each community', () => {
    const cursor: MergedCursor = { perSourceTokens: { humoruniv: '2', todayhumor: null } };

    expect(cursor.perSourceTokens.humoruniv).toBe('2');
    expect(cursor.perSourceTokens.todayhumor).toBeNull();
  });

  it('compares by value', () => {
    const a: MergedCursor = { perSourceTokens: { humoruniv: '1' } };
    const b: MergedCursor = { perSourceTokens: { humoruniv: '1' } };

    expect(a).toEqual(b);
  });

  it('has more when any token is non-null', () => {
    expect(cursorHasMore({ perSourceTokens: { humoruniv: '2', todayhumor: null } })).toBe(true);
  });

  it('has no more when every token is null', () => {
    expect(cursorHasMore({ perSourceTokens: { humoruniv: null, todayhumor: null } })).toBe(false);
  });

  it('has no more when the tokens map is empty', () => {
    expect(cursorHasMore({ perSourceTokens: {} })).toBe(false);
  });
});

describe('MergedPage', () => {
  const item: FeedItem = {
    community: 'humoruniv',
    id: '1',
    title: 't',
    url: 'u',
    recommendCount: 0,
    commentCount: 0,
    viewCount: 0,
  };

  it('is created with items and defaults', () => {
    const page = { items: [], next: null, failedSources: new Set() };

    expect(page.items).toEqual([]);
    expect(page.next).toBeNull();
    expect(page.failedSources.size).toBe(0);
  });

  it('is created with a cursor and failed sources', () => {
    const page = {
      items: [item],
      next: { perSourceTokens: { humoruniv: '1' } },
      failedSources: new Set(['dogdrip' as const]),
    };

    expect(page.items).toHaveLength(1);
    expect(page.next).not.toBeNull();
    expect(page.failedSources.has('dogdrip')).toBe(true);
  });
});
