import { useEffect } from 'react';
import { feedUseCase } from '../service/service_locator';
import type { CommunityId } from '../model/community';
import { feedItemKey, parseFeedItemKey, type FeedItem, type FeedItemKey } from '../model/feed_item';
import { cursorHasMore, type MergedCursor, type MergedPage } from '../model/merged_feed';
import type { PostDetail } from '../model/post_detail';
import type { Result } from '../model/result';
import type { FeedUseCase } from '../use_case/feed_use_case';
import { StateNotifier, useNotifierState } from './state_notifier';
import { useSettings } from './settings_provider';

export interface MergedFeedState {
  items: FeedItem[];
  cursor: MergedCursor | null;
  isLoading: boolean;
  isLoadingMore: boolean;
  error: string | null;
  hasMore: boolean;
  failedSources: Set<CommunityId>;
}

type DetailEntry = { status: 'loading' } | { status: 'loaded'; detail: PostDetail };

export type MergedDetailMap = ReadonlyMap<FeedItemKey, DetailEntry>;

const idleState = (): MergedFeedState => ({
  items: [],
  cursor: null,
  isLoading: false,
  isLoadingMore: false,
  error: null,
  hasMore: true,
  failedSources: new Set(),
});

const pageState = (page: MergedPage): MergedFeedState => ({
  items: page.items,
  cursor: page.next,
  isLoading: false,
  isLoadingMore: false,
  error: null,
  hasMore: page.next !== null && cursorHasMore(page.next),
  failedSources: page.failedSources,
});

/** The state of the feed: what is shown, where it continues, and what is being loaded. */
export class MergedFeedNotifier extends StateNotifier<MergedFeedState> {
  private readonly useCase: FeedUseCase;
  private firstPageLoading: Promise<void> | null = null;
  private firstPageArrived = false;

  constructor(useCase: FeedUseCase) {
    super({ ...idleState(), isLoading: true });
    this.useCase = useCase;
  }

  /**
   * Loads the first page over whatever was shown. A first page that is
   * already loading is joined, not asked for again.
   */
  fetch(): Promise<void> {
    this.firstPageLoading ??= this.loadFirstPage().finally(() => {
      this.firstPageLoading = null;
    });
    return this.firstPageLoading;
  }

  private async loadFirstPage(): Promise<void> {
    this.state = { ...idleState(), isLoading: true };
    this.applyResult(await this.useCase.getMergedFeed({}));
  }

  /**
   * Loads the first page again without the loading skeleton. The current list
   * stays visible while it loads; it is replaced on success and kept on error.
   */
  async refresh(): Promise<void> {
    const result = await this.useCase.getMergedFeed({});
    if (result.ok) {
      this.firstPageArrived = true;
      this.state = pageState(result.value);
    }
  }

  async fetchNextPage(): Promise<void> {
    const { isLoadingMore, hasMore, cursor } = this.state;
    if (isLoadingMore || !hasMore || cursor === null) return;

    this.state = { ...this.state, isLoadingMore: true, error: null };
    const result = await this.useCase.getMergedFeed({ cursor });

    if (!result.ok) {
      // The cursor did not move: the page can be asked for again.
      this.state = { ...this.state, isLoadingMore: false };
      return;
    }

    const shown = new Set(this.state.items.map(feedItemKey));
    const fresh = result.value.items.filter((item) => !shown.has(feedItemKey(item)));
    const next = result.value.next ?? this.state.cursor;
    this.state = {
      items: [...this.state.items, ...fresh],
      cursor: next,
      isLoading: false,
      isLoadingMore: false,
      error: null,
      hasMore: next !== null && cursorHasMore(next),
      failedSources: result.value.failedSources,
    };
  }

  /** Whether the first page has arrived at least once. */
  isLoaded(): boolean {
    return this.firstPageArrived;
  }

  private applyResult(result: Result<MergedPage>): void {
    if (result.ok) this.firstPageArrived = true;
    this.state = result.ok
      ? pageState(result.value)
      : { ...idleState(), error: result.failure.message };
  }
}

/** The post bodies of the feed and of the bookmarks, each asked for once. */
export class MergedDetailNotifier extends StateNotifier<MergedDetailMap> {
  private readonly useCase: FeedUseCase;

  constructor(useCase: FeedUseCase) {
    super(new Map());
    this.useCase = useCase;
  }

  /** Fetches the body of a post unless it is loading or already here. */
  async fetchDetail(key: FeedItemKey): Promise<void> {
    if (this.state.has(key)) return;

    this.state = new Map(this.state).set(key, { status: 'loading' });
    const { community, id } = parseFeedItemKey(key);
    const detail = await this.useCase.getPostDetail(community, id);
    // Cleared while the body was loading: the entry is not wanted any more.
    if (!this.state.has(key)) return;
    this.state = new Map(this.state).set(key, { status: 'loaded', detail });
  }

  /** Drops the cached body of a post, an error card for instance, and fetches it again. */
  async retryDetail(key: FeedItemKey): Promise<void> {
    if (!this.state.has(key)) return;
    const without = new Map(this.state);
    without.delete(key);
    this.state = without;
    await this.fetchDetail(key);
  }

  /** Drops every cached body, so error cards get a fresh fetch on the next load. */
  clear(): void {
    this.state = new Map();
  }
}

let feed: MergedFeedNotifier | undefined;
let details: MergedDetailNotifier | undefined;
/** The communities the feed was last loaded for. */
let loadedFor = '';

/** The one feed of the app, made the first time a screen asks for it. */
export function mergedFeedNotifier(): MergedFeedNotifier {
  feed ??= new MergedFeedNotifier(feedUseCase());
  return feed;
}

/** The bodies of the posts that were shown, made the first time a screen asks for it. */
export function mergedDetailNotifier(): MergedDetailNotifier {
  details ??= new MergedDetailNotifier(feedUseCase());
  return details;
}

/**
 * The feed of the communities that are on. It loads on first use and again
 * whenever that set changes; coming back to the feed loads nothing.
 */
export function useMergedFeed(): MergedFeedState {
  const notifier = mergedFeedNotifier();
  const sources = [...useSettings()].sort().join(',');
  useEffect(() => {
    if (notifier.isLoaded() && loadedFor === sources) return;
    loadedFor = sources;
    void notifier.fetch();
  }, [notifier, sources]);
  return useNotifierState(notifier);
}

export function useMergedDetail(): MergedDetailMap {
  return useNotifierState(mergedDetailNotifier());
}

/**
 * Loads the feed again from its first page. Silently, what is shown stays
 * until the new page has arrived. Cached bodies are dropped too, so an error
 * card gets a fresh fetch instead of staying.
 */
export async function reloadFeed({ silent }: { silent: boolean }): Promise<void> {
  const detail = mergedDetailNotifier();
  if (silent) {
    await mergedFeedNotifier().refresh();
    detail.clear();
  } else {
    detail.clear();
    await mergedFeedNotifier().fetch();
  }
}
