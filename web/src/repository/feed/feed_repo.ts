import type { CommunityId } from '../../model/community';

/** Which communities the feed shows. */
export interface FeedRepo {
  getEnabledCommunities(): Set<CommunityId>;

  /**
   * Whether the user may switch [id] off. Always true for a community that is
   * off: switching it back on is never restricted. False only for the last
   * community that is on, which keeps the feed from going empty.
   */
  canDisable(id: CommunityId): boolean;

  toggleCommunity(id: CommunityId): void;
}
