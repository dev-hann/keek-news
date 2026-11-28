import { describe, expect, it, vi } from 'vitest';
import type { FeedItem } from '../../src/model/feed_item';
import type { MergedPage } from '../../src/model/merged_feed';
import type { LoadedPostDetail, PostDetail } from '../../src/model/post_detail';
import { NetworkFailure, ServerFailure } from '../../src/model/failures';
import { MergedDetailNotifier, MergedFeedNotifier } from '../../src/provider/merged_feed_provider';
import type { FeedUseCase } from '../../src/use_case/feed_use_case';

const item = (id: string, community: FeedItem['community'] = 'humoruniv'): FeedItem => ({
  community,
  id,
  title: `title-${id}`,
  url: `u-${id}`,
  recommendCount: 0,
  commentCount: 0,
  viewCount: 0,
});

const useCaseWith = (overrides: Partial<FeedUseCase>): FeedUseCase =>
  ({ getMergedFeed: vi.fn(), getPostDetail: vi.fn(), ...overrides }) as unknown as FeedUseCase;

describe('MergedFeedNotifier.fetchNextPage', () => {
  it('should append new items and keep hasMore when the cursor has a token', async () => {
    const firstPage: MergedPage = {
      items: [item('1'), item('2')],
      next: { perSourceTokens: { humoruniv: '2' } },
      failedSources: new Set(),
    };
    const secondPage: MergedPage = {
      items: [item('3')],
      next: { perSourceTokens: { humoruniv: '3' } },
      failedSources: new Set(),
    };
    const getMergedFeed = vi
      .fn()
      .mockResolvedValueOnce({ ok: true, value: firstPage })
      .mockResolvedValueOnce({ ok: true, value: secondPage });
    const notifier = new MergedFeedNotifier(useCaseWith({ getMergedFeed }));

    await notifier.fetch();
    await notifier.fetchNextPage();

    expect(notifier.getState().items.map((entry) => entry.id)).toEqual(['1', '2', '3']);
    expect(notifier.getState().hasMore).toBe(true);
    expect(notifier.getState().isLoadingMore).toBe(false);
  });

  it('should end the feed when every source token is null', async () => {
    const firstPage: MergedPage = {
      items: [item('1')],
      next: { perSourceTokens: { humoruniv: '2' } },
      failedSources: new Set(),
    };
    const lastPage: MergedPage = {
      items: [item('2')],
      next: { perSourceTokens: { humoruniv: null } },
      failedSources: new Set(),
    };
    const getMergedFeed = vi
      .fn()
      .mockResolvedValueOnce({ ok: true, value: firstPage })
      .mockResolvedValueOnce({ ok: true, value: lastPage });
    const notifier = new MergedFeedNotifier(useCaseWith({ getMergedFeed }));

    await notifier.fetch();
    await notifier.fetchNextPage();

    expect(notifier.getState().items).toHaveLength(2);
    expect(notifier.getState().hasMore).toBe(false);
  });

  it('should drop items already shown, by community:id', async () => {
    const firstPage: MergedPage = {
      items: [item('1')],
      next: { perSourceTokens: { humoruniv: '2' } },
      failedSources: new Set(),
    };
    const overlapping: MergedPage = {
      items: [item('1'), item('2')],
      next: { perSourceTokens: { humoruniv: '3' } },
      failedSources: new Set(),
    };
    const getMergedFeed = vi
      .fn()
      .mockResolvedValueOnce({ ok: true, value: firstPage })
      .mockResolvedValueOnce({ ok: true, value: overlapping });
    const notifier = new MergedFeedNotifier(useCaseWith({ getMergedFeed }));

    await notifier.fetch();
    await notifier.fetchNextPage();

    expect(notifier.getState().items.map((entry) => entry.id)).toEqual(['1', '2']);
  });

  it('should keep hasMore from the cursor when the next page fails', async () => {
    const firstPage: MergedPage = {
      items: [item('1')],
      next: { perSourceTokens: { humoruniv: '2' } },
      failedSources: new Set(),
    };
    const getMergedFeed = vi
      .fn()
      .mockResolvedValueOnce({ ok: true, value: firstPage })
      .mockResolvedValueOnce({ ok: false, failure: new ServerFailure('network down') });
    const notifier = new MergedFeedNotifier(useCaseWith({ getMergedFeed }));

    await notifier.fetch();
    await notifier.fetchNextPage();

    expect(notifier.getState().items.map((entry) => entry.id)).toEqual(['1']);
    expect(notifier.getState().isLoadingMore).toBe(false);
    expect(notifier.getState().hasMore).toBe(true);
  });

  it('should not fetch when hasMore is false, even with a cursor', async () => {
    const lastPage: MergedPage = {
      items: [item('1')],
      next: { perSourceTokens: { humoruniv: null } },
      failedSources: new Set(),
    };
    const getMergedFeed = vi.fn().mockResolvedValue({ ok: true, value: lastPage });
    const notifier = new MergedFeedNotifier(useCaseWith({ getMergedFeed }));

    await notifier.fetch();

    expect(getMergedFeed).toHaveBeenCalledTimes(1);
    expect(notifier.getState().hasMore).toBe(false);

    await notifier.fetchNextPage();
    expect(getMergedFeed).toHaveBeenCalledTimes(1);
  });
});

describe('MergedFeedNotifier', () => {
  it('tells its listeners whenever the state changes', async () => {
    const page: MergedPage = { items: [item('1')], next: null, failedSources: new Set() };
    const notifier = new MergedFeedNotifier(
      useCaseWith({ getMergedFeed: vi.fn().mockResolvedValue({ ok: true, value: page }) })
    );
    const listener = vi.fn();
    const stop = notifier.subscribe(listener);

    await notifier.fetch();
    expect(listener).toHaveBeenCalled();
    expect(notifier.getState().isLoading).toBe(false);

    stop();
    listener.mockClear();
    await notifier.refresh();
    expect(listener).not.toHaveBeenCalled();
  });

  it('asks for the first page once when it is asked twice while loading', async () => {
    const page: MergedPage = { items: [item('1')], next: null, failedSources: new Set() };
    const getMergedFeed = vi.fn().mockResolvedValue({ ok: true, value: page });
    const notifier = new MergedFeedNotifier(useCaseWith({ getMergedFeed }));

    await Promise.all([notifier.fetch(), notifier.fetch()]);

    expect(getMergedFeed).toHaveBeenCalledTimes(1);

    await notifier.fetch();
    expect(getMergedFeed).toHaveBeenCalledTimes(2);
  });

  it('shows the failure of a first load as the error of the feed', async () => {
    const notifier = new MergedFeedNotifier(
      useCaseWith({
        getMergedFeed: vi.fn().mockResolvedValue({
          ok: false,
          failure: new ServerFailure('All community repos failed'),
        }),
      })
    );

    await notifier.fetch();

    expect(notifier.getState()).toMatchObject({
      isLoading: false,
      error: 'All community repos failed',
      items: [],
    });
  });
});

describe('MergedFeedNotifier.refresh', () => {
  it('should replace the items on success without showing the skeleton', async () => {
    const firstPage: MergedPage = { items: [item('1')], next: null, failedSources: new Set() };
    const refreshed: MergedPage = {
      items: [item('2'), item('3')],
      next: null,
      failedSources: new Set(),
    };
    const getMergedFeed = vi
      .fn()
      .mockResolvedValueOnce({ ok: true, value: firstPage })
      .mockResolvedValueOnce({ ok: true, value: refreshed });
    const notifier = new MergedFeedNotifier(useCaseWith({ getMergedFeed }));

    await notifier.fetch();
    expect(notifier.getState().isLoading).toBe(false);
    expect(notifier.getState().items.map((entry) => entry.id)).toEqual(['1']);

    await notifier.refresh();

    expect(notifier.getState().items.map((entry) => entry.id)).toEqual(['2', '3']);
    expect(notifier.getState().isLoading).toBe(false);
  });

  it('should keep the items shown when the refresh fails', async () => {
    const firstPage: MergedPage = { items: [item('1')], next: null, failedSources: new Set() };
    const getMergedFeed = vi
      .fn()
      .mockResolvedValueOnce({ ok: true, value: firstPage })
      .mockResolvedValueOnce({ ok: false, failure: new ServerFailure('network down') });
    const notifier = new MergedFeedNotifier(useCaseWith({ getMergedFeed }));

    await notifier.fetch();
    await notifier.refresh();

    expect(notifier.getState().items.map((entry) => entry.id)).toEqual(['1']);
    expect(notifier.getState().error).toBeNull();
  });
});

describe('MergedDetailNotifier', () => {
  const key = 'humoruniv:1' as const;
  const loaded: LoadedPostDetail = {
    status: 'loaded',
    id: 1,
    community: 'humoruniv',
    title: 't',
    author: 'a',
    date: new Date(2026, 0, 1),
    contentBlocks: [],
    imageUrls: [],
    recommendCount: 0,
    notRecommendCount: 0,
    viewCount: 0,
    commentCount: 0,
    comments: [],
  };
  const blocked: PostDetail = {
    status: 'error',
    id: 1,
    community: 'humoruniv',
    failure: new NetworkFailure('flake'),
  };

  it('clears the cached error and fetches again on retry', async () => {
    const getPostDetail = vi.fn().mockResolvedValueOnce(blocked).mockResolvedValueOnce(loaded);
    const notifier = new MergedDetailNotifier(useCaseWith({ getPostDetail }));

    await notifier.fetchDetail(key);
    expect(notifier.getState().get(key)).toMatchObject({
      status: 'loaded',
      detail: { status: 'error' },
    });

    await notifier.retryDetail(key);

    expect(getPostDetail).toHaveBeenCalledTimes(2);
    expect(notifier.getState().get(key)).toMatchObject({
      status: 'loaded',
      detail: { status: 'loaded' },
    });
  });

  it('does nothing for a post it never fetched', async () => {
    const getPostDetail = vi.fn().mockResolvedValue(blocked);
    const notifier = new MergedDetailNotifier(useCaseWith({ getPostDetail }));

    await notifier.retryDetail(key);

    expect(getPostDetail).not.toHaveBeenCalled();
  });

  it('asks for a post only once while it is loading or loaded', async () => {
    const getPostDetail = vi.fn().mockResolvedValue(loaded);
    const notifier = new MergedDetailNotifier(useCaseWith({ getPostDetail }));

    const first = notifier.fetchDetail(key);
    await notifier.fetchDetail(key);
    await first;
    await notifier.fetchDetail(key);

    expect(getPostDetail).toHaveBeenCalledTimes(1);
  });

  it('forgets the bodies that have arrived when cleared, and keeps the ones on their way', async () => {
    const other = 'humoruniv:2' as const;
    const getPostDetail = vi.fn().mockResolvedValue(loaded);
    const notifier = new MergedDetailNotifier(useCaseWith({ getPostDetail }));

    await notifier.fetchDetail(key);
    const pending = notifier.fetchDetail(other);
    notifier.clear();

    expect([...notifier.getState().keys()]).toEqual([other]);
    expect(notifier.getState().get(other)).toEqual({ status: 'loading' });

    await pending;

    expect(notifier.getState().get(other)).toMatchObject({ status: 'loaded' });
    expect(notifier.getState().has(key)).toBe(false);
  });

  it('asks again for a post whose body was forgotten, and not for one still on its way', async () => {
    const other = 'humoruniv:2' as const;
    let arrive: (value: LoadedPostDetail) => void = () => undefined;
    const getPostDetail = vi
      .fn()
      .mockResolvedValueOnce(loaded)
      .mockReturnValueOnce(
        new Promise((resolve) => {
          arrive = resolve;
        })
      );
    const notifier = new MergedDetailNotifier(useCaseWith({ getPostDetail }));

    await notifier.fetchDetail(key);
    const pending = notifier.fetchDetail(other);
    notifier.clear();
    await notifier.fetchDetail(key);
    await notifier.fetchDetail(other);

    expect(getPostDetail.mock.calls.map(([, id]) => id)).toEqual(['1', '2', '1']);

    arrive(loaded);
    await pending;
  });

  it('does not retry a post whose body is still on its way: it is neither asked for again nor dropped', async () => {
    const getPostDetail = vi.fn().mockResolvedValue(loaded);
    const notifier = new MergedDetailNotifier(useCaseWith({ getPostDetail }));

    const pending = notifier.fetchDetail(key);
    await notifier.retryDetail(key);
    await pending;

    expect(getPostDetail).toHaveBeenCalledTimes(1);
    expect(notifier.getState().get(key)).toMatchObject({ status: 'loaded' });
  });
});
