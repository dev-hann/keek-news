// @vitest-environment jsdom
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { type Bookmark, bookmarkToJson } from '../../src/model/bookmark';
import type { CommunityId } from '../../src/model/community';
import type { Result } from '../../src/model/result';
import { BookmarkNotifier, bookmarkNotifier } from '../../src/provider/bookmark_provider';
import type { BookmarkUseCase } from '../../src/use_case/bookmark_use_case';

const ok = <T>(value: T): Result<T> => ({ ok: true, value });

function _bookmark({
  community = 'humoruniv',
  id = '1',
  savedAt,
}: {
  community?: CommunityId;
  id?: string;
  savedAt?: Date;
} = {}): Bookmark {
  return {
    community,
    id,
    title: `title-${id}`,
    url: `url-${id}`,
    savedAt: savedAt ?? new Date(2026, 6, 30, 10),
    recommendCount: 0,
    commentCount: 0,
    viewCount: 0,
  };
}

describe('BookmarkNotifier', () => {
  let getAll: ReturnType<typeof vi.fn<BookmarkUseCase['getAll']>>;
  let add: ReturnType<typeof vi.fn<BookmarkUseCase['add']>>;
  let remove: ReturnType<typeof vi.fn<BookmarkUseCase['remove']>>;
  let useCase: BookmarkUseCase;

  beforeEach(() => {
    getAll = vi.fn<BookmarkUseCase['getAll']>();
    add = vi.fn<BookmarkUseCase['add']>();
    remove = vi.fn<BookmarkUseCase['remove']>();
    useCase = {
      getAll,
      isBookmarked: vi.fn<BookmarkUseCase['isBookmarked']>(),
      add,
      remove,
    } as unknown as BookmarkUseCase;
  });

  it('initial state should be empty list', () => {
    getAll.mockResolvedValue(ok([]));
    const notifier = new BookmarkNotifier(useCase);

    expect(notifier.getState()).toEqual([]);
  });

  it('load should populate state from use case', async () => {
    const bookmarks = [_bookmark(), _bookmark({ id: '2' })];
    getAll.mockResolvedValue(ok(bookmarks));
    const notifier = new BookmarkNotifier(useCase);

    await notifier.load();

    expect(notifier.getState()).toHaveLength(2);
    expect(notifier.getState()[0].id).toBe('1');
    expect(notifier.getState()[1].id).toBe('2');
  });

  it('should load what is stored when it is made', async () => {
    // Added for the web: the Dart suite always calls load() itself, but a screen
    // only reads the state, so the first load has to be the constructor's.
    getAll.mockResolvedValue(ok([_bookmark({ id: '5' })]));

    const notifier = new BookmarkNotifier(useCase);
    await vi.waitFor(() => expect(notifier.getState()).toHaveLength(1));

    expect(notifier.getState()[0].id).toBe('5');
    expect(getAll).toHaveBeenCalledTimes(1);
  });

  it('isBookmarked should return true when bookmark in state', async () => {
    getAll.mockResolvedValue(ok([_bookmark({ id: '7' })]));
    const notifier = new BookmarkNotifier(useCase);
    await notifier.load();

    expect(notifier.isBookmarked('humoruniv', '7')).toBe(true);
  });

  it('isBookmarked should return false when bookmark not in state', () => {
    getAll.mockResolvedValue(ok([]));
    const notifier = new BookmarkNotifier(useCase);

    expect(notifier.isBookmarked('humoruniv', '99')).toBe(false);
  });

  it('toggle should add bookmark when not present and return true', async () => {
    add.mockResolvedValue(ok(undefined));
    getAll.mockResolvedValue(ok([]));
    const notifier = new BookmarkNotifier(useCase);
    await notifier.load();

    const result = await notifier.toggle(_bookmark());

    expect(result).toBe(true);
    expect(add).toHaveBeenCalledTimes(1);
  });

  it('toggle should remove bookmark when present and return false', async () => {
    const existing = _bookmark();
    getAll.mockResolvedValue(ok([existing]));
    remove.mockResolvedValue(ok(undefined));
    const notifier = new BookmarkNotifier(useCase);
    await notifier.load();

    const result = await notifier.toggle(existing);

    expect(result).toBe(false);
    expect(remove).toHaveBeenCalledExactlyOnceWith('humoruniv', '1');
  });

  it('toggle add should update state with new bookmark at front', async () => {
    getAll.mockResolvedValue(ok([_bookmark()]));
    add.mockResolvedValue(ok(undefined));
    const notifier = new BookmarkNotifier(useCase);
    await notifier.load();

    await notifier.toggle(_bookmark({ id: '2' }));

    expect(notifier.getState()[0].id).toBe('2');
    expect(notifier.getState()).toHaveLength(2);
  });

  it('toggle remove should update state without removed bookmark', async () => {
    const first = _bookmark();
    const second = _bookmark({ id: '2' });
    getAll.mockResolvedValue(ok([first, second]));
    remove.mockResolvedValue(ok(undefined));
    const notifier = new BookmarkNotifier(useCase);
    await notifier.load();

    await notifier.toggle(second);

    expect(notifier.getState()).toHaveLength(1);
    expect(notifier.getState()[0].id).toBe('1');
  });

  it('remove should delete bookmark from state by key', async () => {
    const first = _bookmark();
    const second = _bookmark({ id: '2' });
    getAll.mockResolvedValue(ok([first, second]));
    remove.mockResolvedValue(ok(undefined));
    const notifier = new BookmarkNotifier(useCase);
    await notifier.load();

    await notifier.remove('humoruniv', '1');

    expect(notifier.getState()).toHaveLength(1);
    expect(notifier.getState()[0].id).toBe('2');
  });
});

describe('bookmarkProvider', () => {
  beforeEach(() => window.localStorage.clear());

  it('should expose BookmarkNotifier wired to use case override', async () => {
    // The web app has no provider to override: the notifier is wired to the
    // page's storage, so the list the mocked use case answered is stored there.
    window.localStorage.setItem(
      'bookmarks',
      JSON.stringify([bookmarkToJson(_bookmark({ id: '5' }))])
    );

    const notifier = bookmarkNotifier();
    await notifier.load();

    expect(notifier.getState()).toHaveLength(1);
    expect(notifier.getState()[0].id).toBe('5');
  });
});
