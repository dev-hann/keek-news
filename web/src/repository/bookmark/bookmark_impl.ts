import { type Bookmark, bookmarkFromJson, bookmarkKey, bookmarkToJson } from '../../model/bookmark';
import type { CommunityId } from '../../model/community';
import type { FeedItemKey } from '../../model/feed_item';
import type { LocalStorageService } from '../../service/local_storage_service';
import type { BookmarkRepo } from './bookmark_repo';

const STORAGE_KEY = 'bookmarks';

const keyOf = (community: CommunityId, id: string): FeedItemKey => `${community}:${id}`;

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value);

/** Keeps the bookmarks in the page's storage, as a JSON list under `bookmarks` as the Flutter app kept them. */
export class BookmarkImpl implements BookmarkRepo {
  private readonly storage: LocalStorageService;

  constructor(storage: LocalStorageService) {
    this.storage = storage;
  }

  getAll(): Bookmark[] {
    const raw = this.storage.getString(STORAGE_KEY);
    if (raw === null) return [];

    let decoded: unknown;
    try {
      decoded = JSON.parse(raw);
    } catch {
      return [];
    }
    if (!Array.isArray(decoded)) return [];

    const result: Bookmark[] = [];
    for (const entry of decoded) {
      if (!isRecord(entry)) continue;
      try {
        result.push(bookmarkFromJson(entry));
      } catch {
        continue;
      }
    }
    return result;
  }

  isBookmarked(community: CommunityId, id: string): boolean {
    const all = this.getAll();
    return all.some((b) => bookmarkKey(b) === keyOf(community, id));
  }

  add(bookmark: Bookmark): void {
    const all = this.getAll();
    const filtered = all.filter((b) => bookmarkKey(b) !== bookmarkKey(bookmark));
    const next = [bookmark, ...filtered];
    this.storage.setString(STORAGE_KEY, JSON.stringify(next.map(bookmarkToJson)));
  }

  remove(community: CommunityId, id: string): void {
    const all = this.getAll();
    const filtered = all.filter((b) => bookmarkKey(b) !== keyOf(community, id));
    this.storage.setString(STORAGE_KEY, JSON.stringify(filtered.map(bookmarkToJson)));
  }
}
