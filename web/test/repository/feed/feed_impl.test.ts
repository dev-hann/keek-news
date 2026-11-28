import { describe, expect, it } from 'vitest';
import type { CommunityId } from '../../../src/model/community';
import { FeedImpl } from '../../../src/repository/feed/feed_impl';
import type { LocalStorageService } from '../../../src/service/local_storage_service';

const STORAGE_KEY = 'enabled_communities';
const SERVED: CommunityId[] = ['humoruniv', 'dogdrip', 'ppomppu'];

/** Storage that keeps what it is given, as a page's storage does. */
function memoryStorage(): LocalStorageService {
  const values = new Map<string, string>();
  return {
    getString: (key) => values.get(key) ?? null,
    setString: (key, value) => void values.set(key, value),
    getStringList: (key) => {
      const raw = values.get(key);
      if (raw === undefined) return null;
      const parsed: unknown = JSON.parse(raw);
      return Array.isArray(parsed) ? parsed.map(String) : null;
    },
    setStringList: (key, value) => void values.set(key, JSON.stringify(value)),
    containsKey: (key) => values.has(key),
    remove: (key) => void values.delete(key),
  };
}

const stored = (names: string[] | null): LocalStorageService => {
  const storage = memoryStorage();
  if (names !== null) storage.setStringList(STORAGE_KEY, names);
  return storage;
};

const readBack = (storage: LocalStorageService): string[] | null =>
  storage.getStringList(STORAGE_KEY);

describe('FeedImpl getEnabledCommunities', () => {
  it('returns every served community when nothing is stored', () => {
    expect(new FeedImpl(stored(null), SERVED).getEnabledCommunities()).toEqual(new Set(SERVED));
  });

  it('returns every served community when an empty list is stored', () => {
    expect(new FeedImpl(stored([]), SERVED).getEnabledCommunities()).toEqual(new Set(SERVED));
  });

  it('decodes stored names into a set of communities', () => {
    expect(new FeedImpl(stored(['dogdrip', 'ppomppu']), SERVED).getEnabledCommunities()).toEqual(
      new Set(['dogdrip', 'ppomppu'])
    );
  });

  it('never returns a community the app does not serve, even when it is stored as enabled', () => {
    // Regression: an older install may hold the name of a community that was
    // taken out. The stored name must not bring it back into the feed.
    expect(new FeedImpl(stored(['dogdrip', 'fmkorea']), SERVED).getEnabledCommunities()).toEqual(
      new Set(['dogdrip'])
    );
  });
});

describe('FeedImpl canDisable', () => {
  it('returns true when more than one community is enabled', () => {
    expect(
      new FeedImpl(stored(['dogdrip', 'ppomppu', 'humoruniv']), SERVED).canDisable('dogdrip')
    ).toBe(true);
  });

  it('returns false when only one community is enabled', () => {
    expect(new FeedImpl(stored(['dogdrip']), SERVED).canDisable('dogdrip')).toBe(false);
  });

  it('returns true for a disabled community even when only one is enabled', () => {
    // Regression: re-enabling was locked out by an older length > 1 check.
    const repo = new FeedImpl(stored(['dogdrip']), SERVED);
    expect(repo.canDisable('ppomppu')).toBe(true);
    expect(repo.canDisable('humoruniv')).toBe(true);
  });

  it('returns true for every disabled community when all but one are off', () => {
    const repo = new FeedImpl(stored(['dogdrip']), SERVED);
    for (const id of SERVED) {
      if (id === 'dogdrip') continue;
      expect(repo.canDisable(id), id).toBe(true);
    }
  });
});

describe('FeedImpl toggleCommunity', () => {
  it('removes the community and stores the rest when more than one is enabled', () => {
    const storage = stored(['dogdrip', 'ppomppu', 'humoruniv']);

    new FeedImpl(storage, SERVED).toggleCommunity('dogdrip');

    const saved = readBack(storage);
    expect(saved).not.toContain('dogdrip');
    expect(saved).toEqual(expect.arrayContaining(['ppomppu', 'humoruniv']));
    expect(saved).toHaveLength(2);
  });

  it('adds the community back and stores it when it was absent', () => {
    const storage = stored(['ppomppu', 'humoruniv']);

    new FeedImpl(storage, SERVED).toggleCommunity('dogdrip');

    const saved = readBack(storage);
    expect(saved).toContain('dogdrip');
    expect(saved).toHaveLength(3);
  });

  it('does nothing when only one community is enabled, so the feed never goes empty', () => {
    const storage = stored(['dogdrip']);

    new FeedImpl(storage, SERVED).toggleCommunity('dogdrip');

    expect(readBack(storage)).toEqual(['dogdrip']);
  });
});

describe('FeedImpl round trip', () => {
  it('reloads the saved set identically', () => {
    const storage = stored(['dogdrip', 'ppomppu']);
    new FeedImpl(storage, SERVED).toggleCommunity('humoruniv');

    expect(new FeedImpl(storage, SERVED).getEnabledCommunities()).toEqual(
      new Set(['dogdrip', 'ppomppu', 'humoruniv'])
    );
  });
});
