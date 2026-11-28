import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { FeedItem } from '../../src/model/feed_item';

const toast = { success: vi.fn(), error: vi.fn() };
const copyText = vi.fn();
const bookmarks = { isBookmarked: vi.fn(), toggle: vi.fn() };

let actions: typeof import('../../src/provider/post_actions');

const post: FeedItem = {
  community: 'humoruniv',
  id: '7',
  title: '제목입니다',
  url: '/board/read.html?table=pds&number=7',
  author: '길동이',
  recommendCount: 3,
  commentCount: 1,
  viewCount: 20,
};

beforeEach(async () => {
  vi.resetModules();
  vi.clearAllMocks();
  vi.doMock('sonner', () => ({ toast }));
  vi.doMock('../../src/utils/clipboard', () => ({ copyText }));
  vi.doMock('../../src/provider/bookmark_provider', () => ({ bookmarkNotifier: () => bookmarks }));
  actions = await import('../../src/provider/post_actions');
});

describe('toggleBookmark', () => {
  it('saves a post that is not saved, with what the listing knows about it, and says nothing', async () => {
    bookmarks.isBookmarked.mockReturnValue(false);
    bookmarks.toggle.mockResolvedValue(true);
    const before = Date.now();

    await actions.toggleBookmark(post);

    expect(bookmarks.toggle).toHaveBeenCalledTimes(1);
    const [saved] = bookmarks.toggle.mock.calls[0];
    expect(saved).toMatchObject({
      community: 'humoruniv',
      id: '7',
      title: '제목입니다',
      url: post.url,
    });
    expect(saved.savedAt.getTime()).toBeGreaterThanOrEqual(before);
    expect(toast.error).not.toHaveBeenCalled();
    expect(toast.success).not.toHaveBeenCalled();
  });

  it('unsaves a post that is saved', async () => {
    bookmarks.isBookmarked.mockReturnValue(true);
    bookmarks.toggle.mockResolvedValue(false);

    await actions.toggleBookmark(post);

    expect(toast.error).not.toHaveBeenCalled();
  });

  it('says so when saving did not work', async () => {
    bookmarks.isBookmarked.mockReturnValue(false);
    bookmarks.toggle.mockResolvedValue(false);

    await actions.toggleBookmark(post);

    expect(toast.error).toHaveBeenCalledWith('저장하지 못했어요');
  });

  it('says so when unsaving did not work', async () => {
    bookmarks.isBookmarked.mockReturnValue(true);
    bookmarks.toggle.mockResolvedValue(true);

    await actions.toggleBookmark(post);

    expect(toast.error).toHaveBeenCalledWith('저장을 취소하지 못했어요');
  });
});

describe('copyPostLink', () => {
  it('copies the address of the post on its site and says so', async () => {
    copyText.mockResolvedValue(true);

    await actions.copyPostLink(post);

    expect(copyText).toHaveBeenCalledWith(
      'https://m.humoruniv.com/board/read.html?table=pds&number=7'
    );
    expect(toast.success).toHaveBeenCalledWith('링크를 복사했어요');
  });

  it('says so when the copy did not work', async () => {
    copyText.mockResolvedValue(false);

    await actions.copyPostLink(post);

    expect(toast.error).toHaveBeenCalledWith('링크를 복사하지 못했습니다');
  });
});
