import { beforeEach, describe, expect, it, vi } from 'vitest';
import { type Bookmark, bookmarkFromJson, bookmarkToJson } from '../../../src/model/bookmark';
import type { CommunityId } from '../../../src/model/community';
import { BookmarkImpl } from '../../../src/repository/bookmark/bookmark_impl';
import type { LocalStorageService } from '../../../src/service/local_storage_service';

const STORAGE_KEY = 'bookmarks';

describe('BookmarkImpl', () => {
  let getString: ReturnType<typeof vi.fn<LocalStorageService['getString']>>;
  let setString: ReturnType<typeof vi.fn<LocalStorageService['setString']>>;
  let repo: BookmarkImpl;

  const bookmark = ({
    community = 'humoruniv',
    id = '1',
    title = 't',
    url = 'u',
  }: {
    community?: CommunityId;
    id?: string;
    title?: string;
    url?: string;
  } = {}): Bookmark => ({
    community,
    id,
    title,
    url,
    savedAt: new Date(1722324000000),
    recommendCount: 0,
    commentCount: 0,
    viewCount: 0,
  });

  const encodeAll = (all: Bookmark[]): string => JSON.stringify(all.map(bookmarkToJson));

  /** The one string written under the key, read back as bookmarks. */
  const persisted = (): Bookmark[] =>
    (JSON.parse(setString.mock.calls[0][1]) as Record<string, unknown>[]).map(bookmarkFromJson);

  beforeEach(() => {
    getString = vi.fn<LocalStorageService['getString']>();
    setString = vi.fn<LocalStorageService['setString']>();
    const storage: LocalStorageService = {
      getString,
      setString,
      getStringList: () => null,
      setStringList: () => undefined,
      containsKey: () => false,
      remove: () => undefined,
    };
    repo = new BookmarkImpl(storage);
  });

  describe('BookmarkImpl getAll', () => {
    it('should decode stored JSON into bookmarks', () => {
      const b = bookmark({ title: 'first' });
      getString.mockReturnValue(encodeAll([b]));

      const result = repo.getAll();

      expect(result).toHaveLength(1);
      expect(result[0].title).toBe('first');
    });

    it('should return empty list when storage empty', () => {
      getString.mockReturnValue(null);

      const result = repo.getAll();

      expect(result).toEqual([]);
    });

    it('should skip malformed entries silently', () => {
      const b = bookmark({ title: 'good' });
      getString.mockReturnValue(
        JSON.stringify([bookmarkToJson(b), { not: 'a bookmark' }, 'string instead of map'])
      );

      const result = repo.getAll();

      expect(result).toHaveLength(1);
      expect(result[0].title).toBe('good');
    });
  });

  describe('BookmarkImpl isBookmarked', () => {
    it('should return true when composite key present', () => {
      getString.mockReturnValue(encodeAll([bookmark()]));

      const result = repo.isBookmarked('humoruniv', '1');

      expect(result).toBe(true);
    });

    it('should return false when composite key absent', () => {
      getString.mockReturnValue(encodeAll([bookmark()]));

      const result = repo.isBookmarked('humoruniv', '99');

      expect(result).toBe(false);
    });

    it('should build composite key as community:id', () => {
      getString.mockReturnValue(encodeAll([bookmark({ community: 'dogdrip', id: '42' })]));

      repo.isBookmarked('dogdrip', '42');

      expect(getString).toHaveBeenCalledExactlyOnceWith(STORAGE_KEY);
    });
  });

  describe('BookmarkImpl add', () => {
    it('should prepend new bookmark and persist as JSON', () => {
      const existing = bookmark({ id: '2', title: 'old' });
      const incoming = bookmark({ title: 'new' });
      getString.mockReturnValue(encodeAll([existing]));

      repo.add(incoming);

      expect(setString).toHaveBeenCalledExactlyOnceWith(STORAGE_KEY, expect.any(String));
      const stored = persisted();
      expect(stored[0].id).toBe('1');
      expect(stored[0].title).toBe('new');
      expect(stored).toHaveLength(2);
    });

    it('should replace existing bookmark with same key', () => {
      const existing = bookmark({ title: 'old' });
      const incoming = bookmark({ title: 'updated' });
      getString.mockReturnValue(encodeAll([existing]));

      repo.add(incoming);

      expect(setString).toHaveBeenCalledExactlyOnceWith(STORAGE_KEY, expect.any(String));
      const stored = persisted();
      expect(stored).toHaveLength(1);
      expect(stored[0].title).toBe('updated');
    });
  });

  describe('BookmarkImpl remove', () => {
    it('should remove matching composite key and persist', () => {
      const keep = bookmark({ id: '2', title: 'keep' });
      const drop = bookmark({ id: '7', title: 'drop' });
      getString.mockReturnValue(encodeAll([keep, drop]));

      repo.remove('humoruniv', '7');

      expect(setString).toHaveBeenCalledExactlyOnceWith(STORAGE_KEY, expect.any(String));
      const stored = persisted();
      expect(stored).toHaveLength(1);
      expect(stored[0].id).toBe('2');
    });

    it('should be no-op when key absent', () => {
      const keep = bookmark({ id: '2', title: 'keep' });
      getString.mockReturnValue(encodeAll([keep]));

      repo.remove('humoruniv', '99');

      expect(setString).toHaveBeenCalledExactlyOnceWith(STORAGE_KEY, expect.any(String));
      const decoded = JSON.parse(setString.mock.calls[0][1]) as unknown[];
      expect(decoded).toHaveLength(1);
    });
  });
});
