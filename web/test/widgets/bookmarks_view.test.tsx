// @vitest-environment jsdom
import { act, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { createElement } from 'react';
import { createRoot } from 'react-dom/client';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { BlockedImage } from '../../src/model/blocked_image';
import type { Bookmark } from '../../src/model/bookmark';
import type { Comment } from '../../src/model/comment';
import type { CommunityId } from '../../src/model/community';
import { NetworkFailure, ServerFailure, type Failure } from '../../src/model/failures';
import type { LoadedPostDetail, PostDetail } from '../../src/model/post_detail';
import { StateNotifier, useNotifierState } from '../../src/provider/state_notifier';

/** The use case the screen reads the bodies of the posts through. */
const fake = { getPostDetail: vi.fn() };

const toast = { success: vi.fn(), error: vi.fn() };
const copyText = vi.fn();

/** What is saved, as the screen sees it: the test fills the list, and what the screen does changes it. */
class SavedPosts extends StateNotifier<Bookmark[]> {
  /** Whether un-saving worked. A test makes it answer false. */
  readonly unsaveWorks = vi.fn(async () => true);

  constructor(saved: Bookmark[]) {
    super(saved);
  }

  isBookmarked(community: CommunityId, id: string): boolean {
    return this.state.some((b) => b.community === community && b.id === id);
  }

  /** Answers whether the post is saved afterwards; a write that failed leaves the list as it was. */
  async toggle(bookmark: Bookmark): Promise<boolean> {
    if (!this.isBookmarked(bookmark.community, bookmark.id)) {
      this.state = [bookmark, ...this.state];
      return true;
    }
    if (await this.unsaveWorks()) this.remove(bookmark.community, bookmark.id);
    return this.isBookmarked(bookmark.community, bookmark.id);
  }

  remove(community: CommunityId, id: string): void {
    this.state = this.state.filter((b) => !(b.community === community && b.id === id));
  }
}

/** The images the user blocked, as the screen sees them. */
class Blocklist extends StateNotifier<BlockedImage[]> {
  constructor(images: BlockedImage[] = []) {
    super(images);
  }
}

const saved = (id: string, extra: Partial<Bookmark> = {}): Bookmark => ({
  community: 'humoruniv',
  id,
  title: `제목 ${id}`,
  url: `/board/read.html?table=pds&number=${id}`,
  savedAt: new Date(2026, 10, 28, 9),
  author: `글쓴이 ${id}`,
  recommendCount: 3,
  commentCount: 1,
  viewCount: 20,
  ...extra,
});

const body = (id: string, extra: Partial<LoadedPostDetail> = {}): LoadedPostDetail => ({
  status: 'loaded',
  id: Number(id),
  community: 'humoruniv',
  title: `제목 ${id}`,
  author: `글쓴이 ${id}`,
  date: new Date(2026, 10, 1),
  contentBlocks: [{ type: 'text', text: `본문 ${id}` }],
  imageUrls: [],
  recommendCount: 3,
  notRecommendCount: 0,
  viewCount: 20,
  commentCount: 1,
  comments: [],
  ...extra,
});

const comment = (id: number, extra: Partial<Comment> = {}): Comment => ({
  id,
  author: '댓글러',
  content: '첫 댓글',
  date: new Date(2026, 10, 1),
  recommendCount: 0,
  isBest: false,
  mediaBlocks: [],
  replies: [],
  ...extra,
});

const failed = (id: string, failure: Failure): PostDetail => ({
  status: 'error',
  id: Number(id),
  community: 'humoruniv',
  failure,
});

const postUrl = (id: string): string =>
  `https://m.humoruniv.com/board/read.html?table=pds&number=${id}`;

let BookmarksView: typeof import('../../src/pages/bookmarks_view').BookmarksView;
let savedPosts: SavedPosts;

interface Screen {
  /** The images the user blocked. */
  blocked?: BlockedImage[];
  /** What the body of a post answers. The body itself, by default. */
  getPostDetail?: (id: string) => PostDetail | Promise<PostDetail>;
}

/** The screen over `saved` posts. */
async function loadBookmarks(saved: Bookmark[], screen: Screen = {}): Promise<void> {
  vi.resetModules();
  fake.getPostDetail.mockReset();
  fake.getPostDetail.mockImplementation(
    async (_community, id) => screen.getPostDetail?.(id) ?? body(id)
  );
  toast.success.mockReset();
  toast.error.mockReset();
  // Copying works, unless a test says otherwise.
  copyText.mockReset();
  copyText.mockResolvedValue(true);
  savedPosts = new SavedPosts(saved);
  const blocklist = new Blocklist(screen.blocked);
  vi.doMock('../../src/service/service_locator', () => ({ feedUseCase: () => fake }));
  vi.doMock('../../src/provider/bookmark_provider', () => ({
    bookmarkNotifier: () => savedPosts,
    useBookmarks: () => useNotifierState(savedPosts),
  }));
  vi.doMock('../../src/provider/blocked_images_provider', () => ({
    useBlockedImages: () => useNotifierState(blocklist),
  }));
  vi.doMock('sonner', () => ({ toast }));
  vi.doMock('../../src/utils/clipboard', () => ({ copyText }));
  ({ BookmarksView } = await import('../../src/pages/bookmarks_view'));
}

/** The card of the post `id`. */
function card(id: string): HTMLElement {
  return screen
    .getByRole('heading', { level: 2, name: `제목 ${id}` })
    .closest('[data-slot="card"]') as HTMLElement;
}

const titles = (): (string | null)[] =>
  screen.getAllByRole('heading', { level: 2 }).map((heading) => heading.textContent);

/** One turn of the event loop. */
const tick = (): Promise<void> => new Promise((resolve) => setTimeout(resolve, 0));

describe('BookmarksView', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('has a title and a way back', async () => {
    await loadBookmarks([]);
    const onBack = vi.fn();

    render(<BookmarksView onBack={onBack} />);
    fireEvent.click(screen.getByRole('button', { name: '뒤로' }));

    expect(screen.getByRole('heading', { level: 1, name: '저장함' })).toBeTruthy();
    expect(onBack).toHaveBeenCalledTimes(1);
  });

  it('says nothing is saved, with what to do about it', async () => {
    await loadBookmarks([]);
    const { container } = render(<BookmarksView onBack={() => undefined} />);

    expect(screen.getByText('저장한 게시물이 없어요')).toBeTruthy();
    expect(screen.getByText('좋아하는 글을 북마크해 보세요')).toBeTruthy();
    const icon = container.querySelector('[role="status"] svg');
    expect(icon?.getAttribute('class')).toContain('lucide-bookmark');
    expect(icon?.getAttribute('aria-hidden')).toBe('true');
    expect(fake.getPostDetail).not.toHaveBeenCalled();
  });

  it('lists the saved posts in the order they were saved, and asks for each body once', async () => {
    const bodies = new Map<string, (body: PostDetail) => void>();
    // Saved later, so listed first.
    await loadBookmarks([saved('2'), saved('1')], {
      getPostDetail: (id) => new Promise<PostDetail>((resolve) => bodies.set(id, resolve)),
    });

    render(<BookmarksView onBack={() => undefined} />);

    // What the listing knows about a post is there before its body is.
    expect(titles()).toEqual(['제목 2', '제목 1']);
    expect(screen.getByText('글쓴이 1')).toBeTruthy();
    expect(screen.getByText('글쓴이 2')).toBeTruthy();
    expect(screen.getAllByRole('progressbar', { name: '이미지 불러오는 중' })).toHaveLength(2);
    expect(fake.getPostDetail).toHaveBeenCalledTimes(2);
    expect(fake.getPostDetail).toHaveBeenCalledWith('humoruniv', '1');
    expect(fake.getPostDetail).toHaveBeenCalledWith('humoruniv', '2');

    await act(async () => {
      bodies.get('1')?.(body('1'));
      bodies.get('2')?.(body('2'));
    });

    expect(screen.getByText('본문 1')).toBeTruthy();
    expect(screen.getByText('본문 2')).toBeTruthy();
    // A body that arrived is not asked for again.
    expect(fake.getPostDetail).toHaveBeenCalledTimes(2);
  });

  it('asks again for the body of a saved post when the bodies that were here are dropped', async () => {
    await loadBookmarks([saved('1')]);

    render(<BookmarksView onBack={() => undefined} />);
    expect(await screen.findByText('본문 1')).toBeTruthy();
    expect(fake.getPostDetail).toHaveBeenCalledTimes(1);

    // What a refresh of the feed does to the bodies that have arrived.
    const { mergedDetailNotifier } = await import('../../src/provider/merged_feed_provider');
    act(() => mergedDetailNotifier().clear());

    await waitFor(() => expect(fake.getPostDetail).toHaveBeenCalledTimes(2));
    expect(await screen.findByText('본문 1')).toBeTruthy();
  });

  it('says of every card that the post is saved', async () => {
    await loadBookmarks([saved('1'), saved('2')]);

    render(<BookmarksView onBack={() => undefined} />);

    const unsave = screen.getAllByRole('button', { name: '저장 취소' });
    expect(unsave).toHaveLength(2);
    expect(unsave[0].getAttribute('aria-pressed')).toBe('true');
    expect(screen.queryByRole('button', { name: '저장' })).toBeNull();
    expect(screen.getAllByRole('button', { name: '링크 복사' })).toHaveLength(2);
  });

  it('unsaves a post from its card, which is why it leaves the list', async () => {
    await loadBookmarks([saved('1'), saved('2')]);

    render(<BookmarksView onBack={() => undefined} />);
    fireEvent.click(within(card('2')).getByRole('button', { name: '저장 취소' }));

    await waitFor(() => expect(titles()).toEqual(['제목 1']));
    expect(savedPosts.getState().map((bookmark) => bookmark.id)).toEqual(['1']);
    expect(toast.error).not.toHaveBeenCalled();
    // The post that stays has its body already: it is not asked for again.
    expect(fake.getPostDetail).toHaveBeenCalledTimes(2);
  });

  it('says so once, and keeps the post, when un-saving did not work', async () => {
    await loadBookmarks([saved('1')]);

    render(<BookmarksView onBack={() => undefined} />);
    savedPosts.unsaveWorks.mockResolvedValueOnce(false);
    fireEvent.click(screen.getByRole('button', { name: '저장 취소' }));

    await waitFor(() =>
      expect(toast.error).toHaveBeenCalledExactlyOnceWith('저장을 취소하지 못했어요')
    );
    expect(titles()).toEqual(['제목 1']);
    expect(toast.success).not.toHaveBeenCalled();
  });

  it('keeps the card of a post whose body failed, with the reason inside it and a way to try again', async () => {
    let tries = 0;
    await loadBookmarks([saved('1')], {
      getPostDetail: (id) => (++tries === 1 ? failed(id, new ServerFailure('flake')) : body(id)),
    });

    render(<BookmarksView onBack={() => undefined} />);

    expect(await screen.findByText('불러오기 실패 — 서버 오류')).toBeTruthy();
    // The card stayed with what was saved: an error card would have no title.
    expect(titles()).toEqual(['제목 1']);
    expect(screen.getByText('글쓴이 1')).toBeTruthy();
    expect(screen.getByRole('button', { name: '저장 취소' })).toBeTruthy();

    fireEvent.click(screen.getByText('다시 시도'));

    expect(await screen.findByText('본문 1')).toBeTruthy();
    expect(fake.getPostDetail).toHaveBeenCalledTimes(2);
  });

  it('keeps the card of a post it cannot reach, and says that what is shown was saved earlier', async () => {
    await loadBookmarks([saved('1')], {
      getPostDetail: (id) => failed(id, new NetworkFailure('offline')),
    });

    render(<BookmarksView onBack={() => undefined} />);

    expect(await screen.findByText('연결할 수 없어 본문을 불러올 수 없어요')).toBeTruthy();
    expect(screen.getByText('저장한 때의 글만 보여요')).toBeTruthy();
    expect(titles()).toEqual(['제목 1']);
  });

  it('keeps the card of a post the site no longer has, and offers no way to try again', async () => {
    await loadBookmarks([saved('1')], {
      getPostDetail: (id) =>
        failed(id, new ServerFailure('gone', { statusCode: 404, headers: {}, bodySnippet: '' })),
    });

    render(<BookmarksView onBack={() => undefined} />);

    expect(await screen.findByText('삭제되었거나 비공개된 게시물이에요')).toBeTruthy();
    expect(titles()).toEqual(['제목 1']);
    expect(screen.queryByText('다시 시도')).toBeNull();
    expect(fake.getPostDetail).toHaveBeenCalledTimes(1);
  });

  it('hides an image the user blocked from the body of a saved post', async () => {
    const A = 'https://example.com/uploads/a.jpg';
    const B = 'https://example.com/uploads/b.jpg';
    await loadBookmarks([saved('1')], {
      blocked: [{ url: A, blockedAt: new Date(2026, 10, 27) }],
      getPostDetail: (id) => body(id, { imageUrls: [A, B] }),
    });

    const { container } = render(<BookmarksView onBack={() => undefined} />);

    // The pager asks for the picture it shows, and never for the blocked one.
    await waitFor(() =>
      expect(
        [...container.querySelectorAll('img')].map((picture) => picture.getAttribute('src'))
      ).toEqual([B])
    );
    expect(fake.getPostDetail).toHaveBeenCalledExactlyOnceWith('humoruniv', '1');
  });

  it('copies the address of a saved post on its site, and says so', async () => {
    await loadBookmarks([saved('1')]);

    render(<BookmarksView onBack={() => undefined} />);
    fireEvent.click(screen.getByRole('button', { name: '링크 복사' }));

    await waitFor(() => expect(toast.success).toHaveBeenCalledExactlyOnceWith('링크를 복사했어요'));
    expect(copyText).toHaveBeenCalledExactlyOnceWith(postUrl('1'));
  });

  it('lists the saved posts on the first view: the empty state is never shown', async () => {
    await loadBookmarks([saved('1'), saved('2')]);

    // Rendered the way the app does it, not inside Testing Library's act.
    const host = document.createElement('div');
    document.body.appendChild(host);
    const shown: string[] = [];
    const observer = new MutationObserver((records) => {
      for (const record of records) {
        shown.push(...[...record.addedNodes].map((node) => node.textContent ?? ''));
      }
    });
    observer.observe(host, { childList: true, subtree: true });
    const root = createRoot(host);
    root.render(createElement(BookmarksView, { onBack() {} }));
    // Long enough for the bodies, which the effect asks for, to be shown.
    for (let turn = 0; turn < 50 && !host.textContent?.includes('본문 2'); turn++) await tick();

    expect(host.textContent).toContain('제목 1');
    expect(host.textContent).toContain('제목 2');
    expect(host.textContent).toContain('본문 2');
    expect(host.textContent).not.toContain('저장한 게시물이 없어요');
    // Nor was it, at any point.
    expect(shown.join('\n')).not.toContain('저장한 게시물이 없어요');

    observer.disconnect();
    await act(() => root.unmount());
    host.remove();
  });

  it('opens the comments of a saved post from its preview, and closes them with 닫기', async () => {
    await loadBookmarks([saved('1')], {
      getPostDetail: (id) =>
        body(id, {
          comments: [comment(1, { replies: [comment(11, { content: '답글' })] })],
        }),
    });

    render(<BookmarksView onBack={() => undefined} />);

    // Two comments listed: the comment and its reply, whatever the site counted.
    fireEvent.click(await screen.findByRole('button', { name: /댓글 2개 모두 보기/ }));

    const sheet = await screen.findByRole('dialog', { name: '댓글 2개' });
    expect(within(sheet).getByText('답글')).toBeTruthy();

    fireEvent.click(within(sheet).getByRole('button', { name: '닫기' }));

    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
  });

  it('opens a picture of a saved post full screen, and offers the media menu, as the feed does', async () => {
    await loadBookmarks([saved('1')], {
      getPostDetail: (id) => body(id, { imageUrls: ['https://example.com/uploads/a.jpg'] }),
    });
    Object.defineProperty(Element.prototype, 'scrollTo', {
      configurable: true,
      value: vi.fn(),
    });

    try {
      render(<BookmarksView onBack={() => undefined} />);

      fireEvent.click(await screen.findByRole('button', { name: '1번째 이미지' }));
      await waitFor(() =>
        expect(document.querySelector('[role="dialog"][aria-label="이미지 보기"]')).toBeTruthy()
      );
      expect(window.history.state).toMatchObject({ overlay: true });
      await act(async () => {
        window.history.back();
        await waitFor(() => expect(document.querySelector('[role="dialog"]')).toBeNull());
      });

      fireEvent.click(screen.getByRole('button', { name: '더보기' }));
      const menu = (await waitFor(() =>
        document.querySelector('[role="dialog"][aria-label="미디어 메뉴"]')
      )) as HTMLElement;
      expect(within(menu).getByRole('button', { name: '갤러리에 저장' })).toBeTruthy();
    } finally {
      delete (Element.prototype as Partial<Element>).scrollTo;
    }
  });
});
