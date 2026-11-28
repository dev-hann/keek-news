import type { CommunityId } from '../../model/community';
import type { FeedItem } from '../../model/feed_item';
import type { LoadedPostDetail } from '../../model/post_detail';

export interface CommunityListResult {
  items: FeedItem[];
  /** Where the community's list continues, or null on its last page. */
  pageToken: string | null;
}

/** One community's posts. A community joins the app by implementing this. */
export interface CommunityRepo {
  readonly communityId: CommunityId;
  fetchLatest(options?: { pageToken?: string | null }): Promise<CommunityListResult>;
  fetchDetail(id: string): Promise<LoadedPostDetail>;
}

export type CommunityRepos = Partial<Record<CommunityId, CommunityRepo>>;
