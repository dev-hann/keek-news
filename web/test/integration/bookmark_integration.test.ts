// @vitest-environment jsdom
import { beforeEach, describe, expect, it } from 'vitest';
import type { Bookmark } from '../../src/model/bookmark';
import type { CommunityId } from '../../src/model/community';
import { BookmarkNotifier } from '../../src/provider/bookmark_provider';
import { BookmarkImpl } from '../../src/repository/bookmark/bookmark_impl';
import type { BookmarkRepo } from '../../src/repository/bookmark/bookmark_repo';
import { BrowserLocalStorageService } from '../../src/service/browser_local_storage_service';
import { BookmarkUseCase } from '../../src/use_case/bookmark_use_case';

describe('Bookmark integration', () => {
  let repository: BookmarkRepo;

  beforeEach(() => {
    window.localStorage.clear();
    repository = new BookmarkImpl(new BrowserLocalStorageService());
  });

  function bookmark({
    community = 'humoruniv',
    id = '1',
    title = '제목',
  }: {
    community?: CommunityId;
    id?: string;
    title?: string;
  } = {}): Bookmark {
    return {
      community,
      id,
      title,
      url: `/url-${id}`,
      author: 'writer',
      savedAt: new Date(2026, 6, 30, 10),
      recommendCount: 0,
      commentCount: 0,
      viewCount: 0,
    };
  }

  const containerWith = (repo: BookmarkRepo): BookmarkNotifier =>
    new BookmarkNotifier(new BookmarkUseCase(repo));

  it('save bookmark persists across repository instances', () => {
    repository.add(bookmark({ id: '100' }));

    const freshRepo = new BookmarkImpl(new BrowserLocalStorageService());
    const all = freshRepo.getAll();

    expect(all).toHaveLength(1);
    expect(all[0].id).toBe('100');
    expect(all[0].title).toBe('제목');
  });

  it('toggle add then remove via notifier updates state and storage', async () => {
    const notifier = containerWith(repository);

    await notifier.load();
    expect(notifier.getState()).toEqual([]);

    const bm = bookmark();
    const added = await notifier.toggle(bm);
    expect(added).toBe(true);
    expect(notifier.getState()).toHaveLength(1);

    const removed = await notifier.toggle(bm);
    expect(removed).toBe(false);
    expect(notifier.getState()).toEqual([]);

    const freshNotifier = containerWith(repository);
    await freshNotifier.load();
    expect(freshNotifier.getState()).toEqual([]);
  });

  it('multiple bookmarks keep most-recent-saved-first order', async () => {
    const notifier = containerWith(repository);

    await notifier.load();
    await notifier.toggle(bookmark());
    await notifier.toggle(bookmark({ id: '2' }));
    await notifier.toggle(bookmark({ id: '3' }));

    expect(notifier.getState().map((b) => b.id)).toEqual(['3', '2', '1']);
  });

  it('isBookmarked reflects state after toggle operations', async () => {
    const notifier = containerWith(repository);
    await notifier.load();

    expect(notifier.isBookmarked('humoruniv', '7')).toBe(false);

    await notifier.toggle(bookmark({ id: '7' }));

    expect(notifier.isBookmarked('humoruniv', '7')).toBe(true);
  });

  it('remove by key deletes only the matching bookmark', async () => {
    const notifier = containerWith(repository);
    await notifier.load();

    await notifier.toggle(bookmark());
    await notifier.toggle(bookmark({ id: '2' }));
    await notifier.remove('humoruniv', '1');

    expect(notifier.getState()).toHaveLength(1);
    expect(notifier.getState()[0].id).toBe('2');
  });
});
