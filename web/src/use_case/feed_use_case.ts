import type { CommunityId } from '../model/community';
import { ParseFailure, ServerFailure } from '../model/failures';
import type { FeedItem } from '../model/feed_item';
import type { MergedCursor, MergedPage } from '../model/merged_feed';
import { looksEmpty, type PostDetail } from '../model/post_detail';
import type { Result } from '../model/result';
import type { CommunityRepo, CommunityRepos } from '../repository/community/community_repo';
import type { FeedRepo } from '../repository/feed/feed_repo';
import { BaseUseCase } from './base_use_case';

export interface MergedFeedParams {
  perSource?: number;
  cursor?: MergedCursor | null;
}

interface FetchOutcome {
  id: CommunityId;
  items: FeedItem[];
  nextToken: string | null;
  failed: boolean;
}

/** Reads the communities the user has on as one feed. */
export class FeedUseCase extends BaseUseCase {
  private readonly repos: CommunityRepos;
  private readonly feedRepo: FeedRepo;

  constructor(repos: CommunityRepos, feedRepo: FeedRepo) {
    super();
    this.repos = repos;
    this.feedRepo = feedRepo;
  }

  getEnabledCommunities(): Set<CommunityId> {
    return this.feedRepo.getEnabledCommunities();
  }

  canDisableCommunity(id: CommunityId): boolean {
    return this.feedRepo.canDisable(id);
  }

  toggleCommunity(id: CommunityId): void {
    this.feedRepo.toggleCommunity(id);
  }

  /** Asks every community that is on for its next page, and merges what came. */
  async getMergedFeed(params: MergedFeedParams = {}): Promise<Result<MergedPage>> {
    const perSource = params.perSource ?? 20;
    const enabled = this.feedRepo.getEnabledCommunities();
    const active = (
      Object.entries(this.repos) as [CommunityId, CommunityRepo | undefined][]
    ).filter(
      (entry): entry is [CommunityId, CommunityRepo] =>
        entry[1] !== undefined && enabled.has(entry[0])
    );

    if (active.length === 0) {
      return { ok: false, failure: new ServerFailure('No active community repos') };
    }

    const cursor = params.cursor ?? null;
    const results = await Promise.all(active.map(([id, repo]) => this.fetchOne(id, repo, cursor)));

    const streams = new Map<CommunityId, FeedItem[]>();
    const nextTokens: Partial<Record<CommunityId, string | null>> = {};
    const failed = new Set<CommunityId>();
    for (const result of results) {
      if (result.failed) {
        failed.add(result.id);
      } else {
        streams.set(result.id, result.items);
        nextTokens[result.id] = result.nextToken;
      }
    }

    if (streams.size === 0) {
      return { ok: false, failure: new ServerFailure('All community repos failed') };
    }

    return {
      ok: true,
      value: merge(streams, nextTokens, perSource * active.length, failed),
    };
  }

  async getPostDetail(community: CommunityId, id: string): Promise<PostDetail> {
    const repo = this.repos[community];
    const parsedId = /^\d+$/.test(id) ? Number(id) : 0;
    if (!repo) {
      return {
        status: 'error',
        id: parsedId,
        community,
        failure: new ServerFailure(`No repo for ${community}`),
      };
    }
    const result = await this.guard(() => repo.fetchDetail(id));
    if (!result.ok) {
      return { status: 'error', id: parsedId, community, failure: result.failure };
    }
    const detail = result.value;
    return looksEmpty(detail)
      ? {
          status: 'error',
          id: detail.id,
          community,
          failure: new ParseFailure('본문 없음 — 차단 또는 구조 변경'),
        }
      : detail;
  }

  private async fetchOne(
    id: CommunityId,
    repo: CommunityRepo,
    cursor: MergedCursor | null
  ): Promise<FetchOutcome> {
    const result = await this.guard(() =>
      repo.fetchLatest({ pageToken: cursor?.perSourceTokens[id] })
    );
    return result.ok
      ? { id, items: result.value.items, nextToken: result.value.pageToken, failed: false }
      : { id, items: [], nextToken: null, failed: true };
  }
}

function merge(
  streams: Map<CommunityId, FeedItem[]>,
  nextTokens: Partial<Record<CommunityId, string | null>>,
  maxItems: number,
  failed: Set<CommunityId>
): MergedPage {
  const all = [...streams.values()].flat();
  const sorted = sortByPublishedAtDescending(all);
  return {
    items: sorted.length > maxItems ? sorted.slice(0, maxItems) : sorted,
    next: { perSourceTokens: { ...nextTokens } },
    failedSources: failed,
  };
}

/** Latest first. Posts without a date come first: nothing says where they belong. */
function sortByPublishedAtDescending(items: FeedItem[]): FeedItem[] {
  const withoutDate = items.filter((item) => item.publishedAt === undefined);
  const dated = items.filter((item) => item.publishedAt !== undefined);
  dated.sort((a, b) => b.publishedAt!.getTime() - a.publishedAt!.getTime());

  const result = [...withoutDate];

  let i = 0;
  let rotation = 0;
  while (i < dated.length) {
    let j = i;
    while (
      j < dated.length &&
      dated[j].publishedAt!.getTime() === dated[i].publishedAt!.getTime()
    ) {
      j++;
    }
    result.push(...interleaveBySource(dated.slice(i, j), rotation));
    rotation++;
    i = j;
  }

  return result;
}

/** Takes turns between the communities of a group with one date, starting one further along each time. */
function interleaveBySource(group: FeedItem[], rotation: number): FeedItem[] {
  if (group.length <= 1) return group;

  const bySource = new Map<CommunityId, FeedItem[]>();
  for (const item of group) {
    const items = bySource.get(item.community) ?? [];
    items.push(item);
    bySource.set(item.community, items);
  }

  const sources = [...bySource.keys()];
  let maxLength = 0;
  for (const items of bySource.values()) {
    maxLength = Math.max(maxLength, items.length);
  }

  const result: FeedItem[] = [];
  for (let index = 0; index < maxLength; index++) {
    for (let s = 0; s < sources.length; s++) {
      const items = bySource.get(sources[(s + rotation) % sources.length])!;
      if (index < items.length) {
        result.push(items[index]);
      }
    }
  }

  return result;
}
