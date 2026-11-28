import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { Comment } from '../../src/model/comment';
import type { CommunityId } from '../../src/model/community';
import type { FeedItem } from '../../src/model/feed_item';
import { NetworkFailure, ParseFailure, ServerFailure } from '../../src/model/failures';
import type { MergedCursor } from '../../src/model/merged_feed';
import type { LoadedPostDetail } from '../../src/model/post_detail';
import type {
  CommunityListResult,
  CommunityRepo,
} from '../../src/repository/community/community_repo';
import type { FeedRepo } from '../../src/repository/feed/feed_repo';
import { FeedUseCase } from '../../src/use_case/feed_use_case';

function repo(communityId: CommunityId) {
  return {
    communityId,
    fetchLatest: vi.fn<(options?: { pageToken?: string | null }) => Promise<CommunityListResult>>(),
    fetchDetail: vi.fn<(id: string) => Promise<LoadedPostDetail>>(),
  } satisfies CommunityRepo;
}

const item = (community: CommunityId, id: string, publishedAt?: Date): FeedItem => ({
  community,
  id,
  title: id,
  url: `u-${id}`,
  recommendCount: 0,
  commentCount: 0,
  viewCount: 0,
  ...(publishedAt ? { publishedAt } : {}),
});

const list = (items: FeedItem[], pageToken: string | null = null): CommunityListResult => ({
  items,
  pageToken,
});

/** A feed with the given communities on; the switches themselves are not under test here. */
const enabled = (...ids: CommunityId[]): FeedRepo => ({
  getEnabledCommunities: () => new Set(ids),
  canDisable: () => true,
  toggleCommunity: () => undefined,
});

describe('FeedUseCase', () => {
  let humoruniv: ReturnType<typeof repo>;
  let dogdrip: ReturnType<typeof repo>;
  let feedRepo: FeedRepo;
  let useCase: FeedUseCase;

  beforeEach(() => {
    humoruniv = repo('humoruniv');
    dogdrip = repo('dogdrip');
    feedRepo = enabled('humoruniv', 'dogdrip');
    useCase = new FeedUseCase({ humoruniv, dogdrip }, feedRepo);
  });

  it('should fan-out to all repos and merge results', async () => {
    humoruniv.fetchLatest.mockResolvedValue(list([item('humoruniv', '1', new Date(2026, 6, 28))]));
    dogdrip.fetchLatest.mockResolvedValue(list([item('dogdrip', '2', new Date(2026, 6, 29))]));

    const result = await useCase.getMergedFeed();

    expect(result.ok).toBe(true);
    expect(result.ok && result.value.items).toHaveLength(2);
    expect(result.ok && result.value.items[0].id).toBe('2');
  });

  it('should isolate failing repos and merge successful ones', async () => {
    humoruniv.fetchLatest.mockRejectedValue(new ServerFailure('humoruniv down'));
    dogdrip.fetchLatest.mockResolvedValue(list([item('dogdrip', '1', new Date(2026, 6, 28))]));

    const result = await useCase.getMergedFeed();

    expect(result.ok).toBe(true);
    expect(result.ok && result.value.failedSources.has('humoruniv')).toBe(true);
    expect(result.ok && result.value.items).toHaveLength(1);
    expect(result.ok && result.value.items[0].community).toBe('dogdrip');
  });

  it('should fail when all repos fail', async () => {
    humoruniv.fetchLatest.mockRejectedValue(new ServerFailure('down'));
    dogdrip.fetchLatest.mockRejectedValue(new ServerFailure('down'));

    expect((await useCase.getMergedFeed()).ok).toBe(false);
  });

  it('should respect the enabled filter', async () => {
    feedRepo = enabled('humoruniv');
    useCase = new FeedUseCase({ humoruniv, dogdrip }, feedRepo);
    humoruniv.fetchLatest.mockResolvedValue(list([item('humoruniv', '1', new Date(2026, 6, 28))]));

    const result = await useCase.getMergedFeed();

    expect(dogdrip.fetchLatest).not.toHaveBeenCalled();
    expect(result.ok).toBe(true);
  });

  it('should keep items without a date on a paginated call', async () => {
    humoruniv.fetchLatest.mockResolvedValue(list([item('humoruniv', '10')], '3'));
    dogdrip.fetchLatest.mockResolvedValue(list([]));
    const cursor: MergedCursor = { perSourceTokens: { humoruniv: '2', dogdrip: '2' } };

    const result = await useCase.getMergedFeed({ cursor });

    expect(result.ok && result.value.items.map((entry) => entry.id)).toEqual(['10']);
  });

  it('should pass the page token of each source to its repo', async () => {
    humoruniv.fetchLatest.mockResolvedValue(list([]));
    dogdrip.fetchLatest.mockResolvedValue(list([]));
    const cursor: MergedCursor = { perSourceTokens: { humoruniv: '2', dogdrip: '5' } };

    await useCase.getMergedFeed({ cursor });

    expect(humoruniv.fetchLatest).toHaveBeenCalledExactlyOnceWith({ pageToken: '2' });
    expect(dogdrip.fetchLatest).toHaveBeenCalledExactlyOnceWith({ pageToken: '5' });
  });

  it('should build the next cursor from the page tokens of the repos', async () => {
    humoruniv.fetchLatest.mockResolvedValue(list([item('humoruniv', '1')], '2'));
    dogdrip.fetchLatest.mockResolvedValue(list([item('dogdrip', '2')]));

    const result = await useCase.getMergedFeed();
    const next = result.ok ? result.value.next : null;

    expect(next).not.toBeNull();
    expect(next?.perSourceTokens.humoruniv).toBe('2');
    expect(next?.perSourceTokens.dogdrip).toBeNull();
    expect(next && Object.values(next.perSourceTokens).some((token) => token != null)).toBe(true);
  });
});

describe('FeedUseCase.getPostDetail', () => {
  const loaded = (overrides: Partial<LoadedPostDetail> = {}): LoadedPostDetail => ({
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
    ...overrides,
  });
  const comment: Comment = {
    id: 1,
    author: 'a',
    content: 'c',
    date: new Date(2026, 0, 1),
    recommendCount: 0,
    isBest: false,
    mediaBlocks: [],
    replies: [],
  };

  let humoruniv: ReturnType<typeof repo>;
  let useCase: FeedUseCase;

  beforeEach(() => {
    humoruniv = repo('humoruniv');
    useCase = new FeedUseCase({ humoruniv }, enabled('humoruniv'));
  });

  it('returns the detail of a post that has content', async () => {
    humoruniv.fetchDetail.mockResolvedValue(loaded({ imageUrls: ['https://e.com/x.jpg'] }));

    const result = await useCase.getPostDetail('humoruniv', '1');

    expect(result.status).toBe('loaded');
  });

  it('returns an error when the repo throws', async () => {
    humoruniv.fetchDetail.mockRejectedValue(new NetworkFailure('connection timed out'));

    const result = await useCase.getPostDetail('humoruniv', '1');

    expect(result.status).toBe('error');
    expect(result).toMatchObject({ community: 'humoruniv', id: 1 });
    expect(result.status === 'error' && result.failure instanceof NetworkFailure).toBe(true);
  });

  it('returns a parse error when the detail looks empty: a block', async () => {
    humoruniv.fetchDetail.mockResolvedValue(loaded());

    const result = await useCase.getPostDetail('humoruniv', '1');

    expect(result.status).toBe('error');
    expect(result.status === 'error' && result.failure instanceof ParseFailure).toBe(true);
  });

  it('returns an error when the community has no repo', async () => {
    const result = await useCase.getPostDetail('ppomppu', '1');

    expect(result.status).toBe('error');
    expect(result.status === 'error' && result.failure instanceof ServerFailure).toBe(true);
  });

  it('does not treat a post with comments as a block', async () => {
    humoruniv.fetchDetail.mockResolvedValue(loaded({ comments: [comment], commentCount: 1 }));

    const result = await useCase.getPostDetail('humoruniv', '1');

    expect(result.status).toBe('loaded');
  });
});
