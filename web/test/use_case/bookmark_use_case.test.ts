import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { Bookmark } from '../../src/model/bookmark';
import type { CommunityId } from '../../src/model/community';
import type { BookmarkRepo } from '../../src/repository/bookmark/bookmark_repo';
import { BookmarkUseCase } from '../../src/use_case/bookmark_use_case';

const _bookmark = ({
  community = 'humoruniv',
  id = '1',
}: {
  community?: CommunityId;
  id?: string;
} = {}): Bookmark => ({
  community,
  id,
  title: 't',
  url: 'u',
  savedAt: new Date(1722324000000),
  recommendCount: 0,
  commentCount: 0,
  viewCount: 0,
});

function mockRepo() {
  return {
    getAll: vi.fn<() => Bookmark[]>(),
    isBookmarked: vi.fn<(community: CommunityId, id: string) => boolean>(),
    add: vi.fn<(bookmark: Bookmark) => void>(),
    remove: vi.fn<(community: CommunityId, id: string) => void>(),
  } satisfies BookmarkRepo;
}

describe('BookmarkUseCase', () => {
  let repo: ReturnType<typeof mockRepo>;
  let useCase: BookmarkUseCase;

  beforeEach(() => {
    repo = mockRepo();
    useCase = new BookmarkUseCase(repo);
  });

  it('getAll delegates to repository.getAll', async () => {
    const bookmarks = [_bookmark(), _bookmark({ id: '2' })];
    repo.getAll.mockReturnValue(bookmarks);

    const result = await useCase.getAll();

    expect(result).toStrictEqual({ ok: true, value: bookmarks });
    expect(repo.getAll).toHaveBeenCalledTimes(1);
  });

  it('isBookmarked delegates to repository.isBookmarked', async () => {
    repo.isBookmarked.mockReturnValue(true);

    const result = await useCase.isBookmarked('humoruniv', '1');

    expect(result.ok && result.value).toBe(true);
    expect(repo.isBookmarked).toHaveBeenCalledExactlyOnceWith('humoruniv', '1');
  });

  it('add delegates to repository.add', async () => {
    const bookmark = _bookmark({ id: '7' });

    const result = await useCase.add(bookmark);

    expect(result.ok).toBe(true);
    expect(repo.add).toHaveBeenCalledExactlyOnceWith(bookmark);
  });

  it('remove delegates to repository.remove', async () => {
    const result = await useCase.remove('humoruniv', '7');

    expect(result.ok).toBe(true);
    expect(repo.remove).toHaveBeenCalledExactlyOnceWith('humoruniv', '7');
  });
});
