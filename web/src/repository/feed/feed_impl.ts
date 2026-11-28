import { communityIds, type CommunityId } from '../../model/community';
import type { LocalStorageService } from '../../service/local_storage_service';
import type { FeedRepo } from './feed_repo';

const ENABLED_KEY = 'enabled_communities';

export class FeedImpl implements FeedRepo {
  private readonly storage: LocalStorageService;
  /** The communities the app serves. Nothing outside them is ever on, whatever is stored. */
  private readonly served: readonly CommunityId[];

  constructor(storage: LocalStorageService, served: readonly CommunityId[]) {
    this.storage = storage;
    this.served = served;
  }

  getEnabledCommunities(): Set<CommunityId> {
    const stored = this.storage.getStringList(ENABLED_KEY);
    // An older install may still hold the name of a community the app no longer
    // serves, or never served: it must not come back through the stored selection.
    const enabled =
      stored === null || stored.length === 0
        ? this.served
        : stored.filter((name): name is CommunityId =>
            (communityIds as readonly string[]).includes(name)
          );
    return new Set(enabled.filter((id) => this.served.includes(id)));
  }

  canDisable(id: CommunityId): boolean {
    const enabled = this.getEnabledCommunities();
    // A community that is off can always be turned back on; only the last one
    // that is on is locked, to keep the feed from going empty.
    return !enabled.has(id) || enabled.size > 1;
  }

  toggleCommunity(id: CommunityId): void {
    const next = new Set(this.getEnabledCommunities());
    if (next.has(id)) {
      if (next.size <= 1) return;
      next.delete(id);
    } else {
      next.add(id);
    }
    this.storage.setStringList(ENABLED_KEY, [...next]);
  }
}
