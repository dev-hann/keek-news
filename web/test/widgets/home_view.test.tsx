// @vitest-environment jsdom
import { act, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import type { BlockedImage } from '../../src/model/blocked_image';
import type { Bookmark } from '../../src/model/bookmark';
import type { Comment } from '../../src/model/comment';
import type { CommunityId } from '../../src/model/community';
import type { FeedItem } from '../../src/model/feed_item';
import { NetworkFailure } from '../../src/model/failures';
import type { MergedPage } from '../../src/model/merged_feed';
import type { LoadedPostDetail } from '../../src/model/post_detail';

/** The use case the screens see. Replaced in every test: the modules are loaded again, so their singletons start fresh. */
const fake = {
  getMergedFeed: vi.fn(),
  getPostDetail: vi.fn(),
  getEnabledCommunities: vi.fn(() => new Set<CommunityId>(['humoruniv'])),
  canDisableCommunity: vi.fn(() => false),
  toggleCommunity: vi.fn(),
};

/** What is saved, for the screens to see: the test reads and empties this list. */
const saved: Bookmark[] = [];
const bookmarkUseCase = {
  getAll: vi.fn(async () => ({ ok: true, value: [...saved] })),
  isBookmarked: vi.fn(
    async (community: CommunityId, id: string) =>
      ({ ok: true, value: saved.some((b) => b.community === community && b.id === id) }) as const
  ),
  add: vi.fn(async (bookmark: Bookmark) => {
    saved.unshift(bookmark);
    return { ok: true, value: undefined } as const;
  }),
  remove: vi.fn(async (community: CommunityId, id: string) => {
    const at = saved.findIndex((b) => b.community === community && b.id === id);
    if (at >= 0) saved.splice(at, 1);
    return { ok: true, value: undefined } as const;
  }),
};

/** The blocklist use case the screens see, over a list the test controls. */
const blocked: BlockedImage[] = [];
/** Told when the list changed, as the repository tells the notifier. */
const blocklistListeners = new Set<() => void>();
const blockImageUseCase = {
  changes: {
    subscribe: (listener: () => void) => {
      blocklistListeners.add(listener);
      return () => blocklistListeners.delete(listener);
    },
  },
  isHashBlocked: () => false,
  getAll: vi.fn(async () => ({ ok: true, value: [...blocked] })),
  add: vi.fn(async (url: string) => {
    blocked.push({ url, blockedAt: new Date(0) });
    blocklistListeners.forEach((listener) => listener());
    return { ok: true, value: undefined } as const;
  }),
  remove: vi.fn(async (url: string) => {
    const at = blocked.findIndex((image) => image.url === url);
    if (at >= 0) blocked.splice(at, 1);
    blocklistListeners.forEach((listener) => listener());
    return { ok: true, value: undefined } as const;
  }),
};
const savedMedia = { call: vi.fn() };
const sharedMedia = { call: vi.fn() };
const copyText = vi.fn();
const dialogs = (): Element[] => [...document.querySelectorAll('[role="dialog"]')];
const dialogNamed = (name: string): Element | null =>
  document.querySelector(`[role="dialog"][aria-label="${name}"]`);

const post = (id: string, extra: Partial<FeedItem> = {}): FeedItem => ({
  community: 'humoruniv',
  id,
  title: `제목 ${id}`,
  url: `/board/read.html?table=pds&number=${id}`,
  author: `글쓴이 ${id}`,
  recommendCount: 3,
  commentCount: 1,
  viewCount: 20,
  ...extra,
});

const body = (id: string, text = '본문 내용'): LoadedPostDetail => ({
  status: 'loaded',
  id: Number(id),
  community: 'humoruniv',
  title: `제목 ${id}`,
  author: `글쓴이 ${id}`,
  date: new Date(2026, 10, 1),
  contentBlocks: [{ type: 'text', text }],
  imageUrls: [],
  recommendCount: 3,
  notRecommendCount: 0,
  viewCount: 20,
  commentCount: 1,
  comments: [],
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

const page = (items: FeedItem[], next: MergedPage['next'] = null): MergedPage => ({
  items,
  next,
  failedSources: new Set(),
});
const ok = (value: MergedPage) => ({ ok: true, value });

let HomeView: typeof import('../../src/pages/home_view').HomeView;

async function loadHome(): Promise<void> {
  vi.resetModules();
  fake.getMergedFeed.mockReset();
  fake.getPostDetail.mockReset();
  // A post always has a body to fetch: a test that cares replaces it for its own calls.
  fake.getPostDetail.mockImplementation(async (_community, id) => body(String(id)));
  saved.length = 0;
  blocked.length = 0;
  blocklistListeners.clear();
  savedMedia.call.mockReset();
  savedMedia.call.mockResolvedValue({ ok: true });
  sharedMedia.call.mockReset();
  sharedMedia.call.mockResolvedValue({ ok: true });
  copyText.mockReset();
  copyText.mockResolvedValue(true);
  vi.doMock('../../src/utils/clipboard', () => ({ copyText }));
  vi.doMock('../../src/service/service_locator', () => ({
    feedUseCase: () => fake,
    bookmarkUseCase: () => bookmarkUseCase,
    blockImageUseCase: () => blockImageUseCase,
    saveMediaUseCase: () => savedMedia,
    shareMediaUseCase: () => sharedMedia,
  }));
  ({ HomeView } = await import('../../src/pages/home_view'));
}

/** Serves a second community too, the way a real one is added: through the registry. */
async function serveTwoCommunities(): Promise<void> {
  vi.doMock('../../src/model/community', async (importOriginal) => {
    const actual = await importOriginal<typeof import('../../src/model/community')>();
    const dogdrip = {
      id: 'dogdrip' as const,
      shortName: '개드립',
      displayName: 'DogDrip',
      brandColor: '#A855F7',
      baseUrl: 'https://www.dogdrip.net',
    };
    return {
      ...actual,
      registeredCommunityIds: [...actual.registeredCommunityIds, 'dogdrip' as const],
      communities: { ...actual.communities, dogdrip },
      registeredCommunities: [...actual.registeredCommunities, dogdrip],
    };
  });
}

/** Nothing lays out a page here: give the parts the feed reads a height. */
function layout(documentHeight: number): void {
  vi.spyOn(document.documentElement, 'scrollHeight', 'get').mockReturnValue(documentHeight);
}

/** What the pictures of the page are asked for, as `src`, in the order of the page. */
const pictureSources = (container: HTMLElement): (string | null)[] =>
  [...container.querySelectorAll('img')].map((image) => image.getAttribute('src'));

describe('HomeView', () => {
  beforeEach(async () => {
    window.localStorage.clear();
    window.scrollTo = vi.fn();
    window.matchMedia = vi.fn().mockReturnValue({ matches: false }) as never;
    await loadHome();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('shows skeletons while the first page loads, then the posts', async () => {
    let arrive: (value: MergedPage) => void = () => undefined;
    fake.getMergedFeed.mockReturnValue(
      new Promise((resolve) => {
        arrive = (value: MergedPage) => resolve(ok(value));
      })
    );
    fake.getPostDetail.mockResolvedValue(body('1'));
    layout(5000);

    render(<HomeView onOpenSettings={() => undefined} />);
    expect(screen.getAllByRole('progressbar', { name: '게시글 불러오는 중' })).toHaveLength(4);

    await act(async () => arrive(page([post('1'), post('2')])));

    expect(await screen.findByText('제목 1')).toBeTruthy();
    expect(screen.getByText('제목 2')).toBeTruthy();
    expect(screen.queryByRole('progressbar', { name: '게시글 불러오는 중' })).toBeNull();
  });

  it('names the screen after the community and keeps no tab bar for one community', async () => {
    fake.getMergedFeed.mockResolvedValue(ok(page([])));
    layout(5000);

    render(<HomeView onOpenSettings={() => undefined} />);

    expect(screen.getByRole('heading', { level: 1, name: '웃긴대학' })).toBeTruthy();
    expect(screen.queryByRole('tablist')).toBeNull();
  });

  it('asks for the body of each post once', async () => {
    fake.getMergedFeed.mockResolvedValue(ok(page([post('1'), post('2')])));
    fake.getPostDetail.mockImplementation(async (_community, id) => body(id));
    layout(5000);

    render(<HomeView onOpenSettings={() => undefined} />);

    expect((await screen.findAllByText('본문 내용', { exact: true })).length).toBe(2);
    expect(fake.getPostDetail).toHaveBeenCalledTimes(2);
    expect(fake.getPostDetail).toHaveBeenCalledWith('humoruniv', '1');
    expect(fake.getPostDetail).toHaveBeenCalledWith('humoruniv', '2');
  });

  it('shows an error with a way to try again when the first page fails', async () => {
    fake.getMergedFeed.mockResolvedValueOnce({ ok: false, failure: new NetworkFailure('timeout') });
    layout(5000);

    render(<HomeView onOpenSettings={() => undefined} />);

    expect(await screen.findByRole('alert')).toBeTruthy();
    expect(screen.getByText('다시 시도')).toBeTruthy();

    fake.getMergedFeed.mockResolvedValue(ok(page([post('1')])));
    fake.getPostDetail.mockImplementation(async (_community, id) => body(id));
    fireEvent.click(screen.getByText('다시 시도'));

    expect(await screen.findByText('제목 1')).toBeTruthy();
    expect(fake.getMergedFeed).toHaveBeenCalledTimes(2);
  });

  it('says so when there is no post', async () => {
    fake.getMergedFeed.mockResolvedValue(ok(page([])));
    layout(5000);

    render(<HomeView onOpenSettings={() => undefined} />);

    expect(await screen.findByText('게시글이 없습니다.')).toBeTruthy();
  });

  it('shows a post whose body failed as an error card, and tries again when asked', async () => {
    fake.getMergedFeed.mockResolvedValue(ok(page([post('1')])));
    fake.getPostDetail.mockResolvedValueOnce({
      status: 'error',
      id: 1,
      community: 'humoruniv',
      failure: new NetworkFailure('flake'),
    });
    layout(5000);

    render(<HomeView onOpenSettings={() => undefined} />);

    expect(await screen.findByText('불러오기 실패 — 네트워크 오류')).toBeTruthy();

    fake.getPostDetail.mockResolvedValueOnce(body('1'));
    fireEvent.click(screen.getByText('다시 시도'));

    expect(await screen.findByText('본문 내용', { exact: true })).toBeTruthy();
    expect(fake.getPostDetail).toHaveBeenCalledTimes(2);
  });

  it('offers no refresh button, and its title is plain text', async () => {
    fake.getMergedFeed.mockResolvedValue(ok(page([post('1')])));
    layout(5000);

    render(<HomeView onOpenSettings={() => undefined} />);

    expect(screen.queryByRole('button', { name: '새로고침' })).toBeNull();
    const title = screen.getByRole('heading', { level: 1, name: '웃긴대학' });
    expect(title.querySelector('button')).toBeNull();
    fireEvent.click(title);
    expect(fake.getMergedFeed).toHaveBeenCalledTimes(1);
  });

  it('loads the first page again from the way up, without the skeleton, and keeps the posts until it has arrived', async () => {
    fake.getMergedFeed.mockResolvedValue(ok(page([post('1')])));
    fake.getPostDetail.mockImplementation(async (_community, id) => body(id));
    layout(5000);
    render(<HomeView onOpenSettings={() => undefined} />);
    expect(await screen.findByText('제목 1')).toBeTruthy();

    let arrive: (value: MergedPage) => void = () => undefined;
    fake.getMergedFeed.mockReturnValueOnce(
      new Promise((resolve) => {
        arrive = (value: MergedPage) => resolve(ok(value));
      })
    );
    // The way up loads the first page again.
    fireEvent.click(screen.getByRole('button', { name: '맨 위로' }));

    expect(window.scrollTo).toHaveBeenCalledWith(0, 0);
    expect(screen.getByText('제목 1')).toBeTruthy();
    expect(screen.queryByRole('progressbar', { name: '게시글 불러오는 중' })).toBeNull();

    await act(async () => arrive(page([post('2')])));
    expect(await screen.findByText('제목 2')).toBeTruthy();
    expect(screen.queryByText('제목 1')).toBeNull();
  });

  it('asks again for the body of a post that the new page still holds, so no card is left without one', async () => {
    // The usual refresh: the first page has hardly changed, and the same posts are shown again.
    fake.getMergedFeed.mockResolvedValue(ok(page([post('1')])));
    fake.getPostDetail.mockImplementation(async (_community, id) => body(id));
    layout(5000);
    render(<HomeView onOpenSettings={() => undefined} />);
    expect(await screen.findAllByText('본문 내용', { exact: true })).toHaveLength(1);
    expect(fake.getPostDetail).toHaveBeenCalledTimes(1);

    fireEvent.click(screen.getByRole('button', { name: '맨 위로' }));

    await waitFor(() => expect(fake.getPostDetail).toHaveBeenCalledTimes(2));
    expect(fake.getPostDetail).toHaveBeenLastCalledWith('humoruniv', '1');
    expect(await screen.findAllByText('본문 내용', { exact: true })).toHaveLength(1);
  });

  it('does not ask twice for a post whose body is still on its way when the page is refreshed', async () => {
    fake.getMergedFeed.mockResolvedValue(ok(page([post('1')])));
    let arrive: (value: LoadedPostDetail) => void = () => undefined;
    fake.getPostDetail.mockReturnValueOnce(
      new Promise((resolve) => {
        arrive = resolve;
      })
    );
    layout(5000);
    render(<HomeView onOpenSettings={() => undefined} />);
    expect(await screen.findByText('제목 1')).toBeTruthy();

    fireEvent.click(screen.getByRole('button', { name: '맨 위로' }));
    await waitFor(() => expect(fake.getMergedFeed).toHaveBeenCalledTimes(2));

    expect(fake.getPostDetail).toHaveBeenCalledTimes(1);
    await act(async () => arrive(body('1')));
    expect(await screen.findByText('본문 내용', { exact: true })).toBeTruthy();
    expect(fake.getPostDetail).toHaveBeenCalledTimes(1);
  });

  it('asks for the next page at 85% of the list', async () => {
    const next = { perSourceTokens: { humoruniv: '1' as const } };
    fake.getMergedFeed.mockResolvedValueOnce(ok(page([post('1')], next)));
    layout(5000);
    render(<HomeView onOpenSettings={() => undefined} />);
    await screen.findByText('제목 1');

    fake.getMergedFeed.mockResolvedValueOnce(ok(page([post('2')], next)));
    fake.getPostDetail.mockImplementation(async (_community, id) => body(id));
    const scroll = vi.spyOn(window, 'scrollY', 'get');
    scroll.mockReturnValue(5000 * 0.9);
    fireEvent.scroll(window);

    await waitFor(() => expect(fake.getMergedFeed).toHaveBeenCalledTimes(2));
    expect(fake.getMergedFeed).toHaveBeenLastCalledWith({ cursor: next });
  });

  it('shows a tab per community once there are two, and the tab picks what is shown', async () => {
    await serveTwoCommunities();
    await loadHome();
    fake.getEnabledCommunities.mockReturnValue(new Set<CommunityId>(['humoruniv', 'dogdrip']));
    fake.getMergedFeed.mockResolvedValue(
      ok(page([post('1'), post('2', { community: 'dogdrip', title: '개드립 글' })]))
    );
    fake.getPostDetail.mockImplementation(async (_community, id) => body(id));
    layout(5000);

    render(<HomeView onOpenSettings={() => undefined} />);
    expect(await screen.findByText('제목 1')).toBeTruthy();
    expect(screen.queryByText('개드립 글')).toBeNull();

    const tabs = screen.getAllByRole('tab');
    expect(tabs.map((tab) => tab.textContent)).toEqual(['웃대', '개드립']);
    expect(screen.getByRole('heading', { level: 1, name: '웃긴대학' })).toBeTruthy();

    fireEvent.click(screen.getByRole('tab', { name: '개드립' }));

    expect(screen.getByRole('heading', { level: 1, name: 'DogDrip' })).toBeTruthy();
    expect(screen.queryByText('제목 1')).toBeNull();
    vi.doUnmock('../../src/model/community');
  });

  it('opens settings from the app bar', async () => {
    fake.getMergedFeed.mockResolvedValue(ok(page([])));
    layout(5000);
    const onOpenSettings = vi.fn();

    render(<HomeView onOpenSettings={onOpenSettings} />);
    fireEvent.click(screen.getByRole('button', { name: '설정' }));

    expect(onOpenSettings).toHaveBeenCalledTimes(1);
  });

  it('saves a post from its card, and unsaves it from the same button', async () => {
    fake.getMergedFeed.mockResolvedValue(ok(page([post('1')])));
    fake.getPostDetail.mockResolvedValue(body('1'));
    layout(5000);

    render(<HomeView onOpenSettings={() => undefined} />);

    fireEvent.click(await screen.findByRole('button', { name: '저장' }));
    expect(await screen.findByRole('button', { name: '저장 취소' })).toBeTruthy();
    expect(saved.map((bookmark) => bookmark.id)).toEqual(['1']);

    fireEvent.click(screen.getByRole('button', { name: '저장 취소' }));
    expect(await screen.findByRole('button', { name: '저장' })).toBeTruthy();
    expect(saved).toEqual([]);
  });

  it('opens the comments of a post from its card, and closes them with 닫기', async () => {
    fake.getMergedFeed.mockResolvedValue(ok(page([post('1')])));
    fake.getPostDetail.mockResolvedValue({
      ...body('1'),
      comments: [comment(1, { replies: [comment(11, { content: '답글' })] })],
    });
    layout(5000);

    render(<HomeView onOpenSettings={() => undefined} />);

    // Two comments listed: the comment and its reply, whatever the site counted.
    fireEvent.click(await screen.findByRole('button', { name: /댓글 2개 모두 보기/ }));

    const sheet = await screen.findByRole('dialog', { name: '댓글 2개' });
    expect(within(sheet).getByText('답글')).toBeTruthy();

    fireEvent.click(within(sheet).getByRole('button', { name: '닫기' }));

    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    expect(screen.getByRole('button', { name: /댓글 2개 모두 보기/ })).toBeTruthy();
  });

  it('leaves a blocked image out of the post that shows it', async () => {
    blocked.push({ url: 'https://e.com/blocked.jpg', blockedAt: new Date(0) });
    fake.getMergedFeed.mockResolvedValue(ok(page([post('1')])));
    fake.getPostDetail.mockResolvedValue({
      ...body('1'),
      contentBlocks: [],
      imageUrls: ['https://e.com/blocked.jpg', 'https://e.com/shown.jpg'],
    });
    layout(5000);

    const { container } = render(<HomeView onOpenSettings={() => undefined} />);

    // The pager asks for the picture it shows, and never for the blocked one.
    await waitFor(() => expect(pictureSources(container)).toEqual(['https://e.com/shown.jpg']));
  });

  describe('the media of a post', () => {
    beforeAll(() => {
      // The viewer pages by scrolling its own element, and jsdom does not scroll.
      Object.defineProperty(Element.prototype, 'scrollTo', { configurable: true, value: vi.fn() });
    });
    afterAll(() => {
      delete (Element.prototype as Partial<Element>).scrollTo;
    });
    const pictures = (urls: string[]): LoadedPostDetail => ({
      ...body('1'),
      contentBlocks: [],
      imageUrls: urls,
    });
    const shown = async () => {
      fake.getMergedFeed.mockResolvedValue(ok(page([post('1')])));
      layout(5000);
      const view = render(<HomeView onOpenSettings={() => undefined} />);
      await screen.findByRole('button', { name: '1번째 이미지' });
      return view;
    };

    it('opens an image full screen from a tap on it, and Back closes the viewer before the page', async () => {
      fake.getPostDetail.mockResolvedValue(
        pictures(['https://e.com/a.jpg', 'https://e.com/b.jpg'])
      );
      await shown();

      fireEvent.click(screen.getByRole('button', { name: '1번째 이미지' }));

      expect(await waitFor(() => dialogNamed('이미지 보기'))).toBeTruthy();
      expect(window.history.state).toMatchObject({ overlay: true });

      // The system Back: the entry of the overlay is left.
      await act(async () => {
        window.history.back();
        await waitFor(() => expect(dialogs()).toHaveLength(0));
      });
      expect(window.location.pathname).toBe('/');
    });

    it('offers the media menu from ⋯, with what an image is good for, and copies its address', async () => {
      fake.getPostDetail.mockResolvedValue(pictures(['https://e.com/a.jpg']));
      await shown();

      fireEvent.click(screen.getByRole('button', { name: '더보기' }));

      const sheet = (await waitFor(() => dialogNamed('미디어 메뉴'))) as HTMLElement;
      expect(
        [...sheet.querySelectorAll('button')].map((row) => row.textContent?.trim()).filter(Boolean)
      ).toEqual(['갤러리에 저장', '공유', 'URL 복사', '이미지 차단']);

      fireEvent.click(within(sheet).getByRole('button', { name: 'URL 복사' }));

      await waitFor(() => expect(copyText).toHaveBeenCalledWith('https://e.com/a.jpg'));
      await waitFor(() => expect(dialogs()).toHaveLength(0));
    });

    it('saves and shares the picture through the use cases, and closes the menu either way', async () => {
      fake.getPostDetail.mockResolvedValue(pictures(['https://e.com/a.jpg']));
      await shown();

      fireEvent.click(screen.getByRole('button', { name: '더보기' }));
      const sheet = (await waitFor(() => dialogNamed('미디어 메뉴'))) as HTMLElement;
      fireEvent.click(within(sheet).getByRole('button', { name: '갤러리에 저장' }));

      await waitFor(() => expect(savedMedia.call).toHaveBeenCalledTimes(1));
      expect(savedMedia.call.mock.calls[0][0]).toEqual({
        url: 'https://e.com/a.jpg',
        kind: 'image',
      });
      await waitFor(() => expect(dialogs()).toHaveLength(0));

      fireEvent.click(screen.getByRole('button', { name: '더보기' }));
      const again = (await waitFor(() => dialogNamed('미디어 메뉴'))) as HTMLElement;
      fireEvent.click(within(again).getByRole('button', { name: '공유' }));

      await waitFor(() => expect(sharedMedia.call).toHaveBeenCalledTimes(1));
      expect(sharedMedia.call.mock.calls[0][0].url).toBe('https://e.com/a.jpg');
    });

    it('blocks the picture from the menu of the viewer: the viewer, now empty, closes and the card loses it', async () => {
      fake.getPostDetail.mockResolvedValue(pictures(['https://e.com/a.jpg']));
      const { container } = await shown();
      fireEvent.click(screen.getByRole('button', { name: '1번째 이미지' }));
      const viewer = (await waitFor(() => dialogNamed('이미지 보기'))) as HTMLElement;

      fireEvent.click(within(viewer).getByRole('button', { name: '더보기' }));
      const sheet = (await waitFor(() => dialogNamed('미디어 메뉴'))) as HTMLElement;
      fireEvent.click(within(sheet).getByRole('button', { name: '이미지 차단' }));

      await waitFor(() =>
        expect(blockImageUseCase.add).toHaveBeenCalledWith('https://e.com/a.jpg')
      );
      await waitFor(() => expect(dialogs()).toHaveLength(0));
      expect(container.querySelector('img[src="https://e.com/a.jpg"]')).toBeNull();
    });

    it('offers no 차단 for a video, only its address', async () => {
      fake.getPostDetail.mockResolvedValue({
        ...body('1'),
        contentBlocks: [
          { type: 'video', url: 'https://e.com/v.mp4', thumbnailUrl: 'https://e.com/v.jpg' },
        ],
        imageUrls: [],
      });
      fake.getMergedFeed.mockResolvedValue(ok(page([post('1')])));
      layout(5000);
      render(<HomeView onOpenSettings={() => undefined} />);

      fireEvent.click(await screen.findByRole('button', { name: '더보기' }));

      const sheet = (await waitFor(() => dialogNamed('미디어 메뉴'))) as HTMLElement;
      expect(within(sheet).queryByRole('button', { name: '이미지 차단' })).toBeNull();
      expect(within(sheet).getByRole('button', { name: 'URL 복사' })).toBeTruthy();
    });
  });

  describe('the media of a comment', () => {
    beforeAll(() => {
      Object.defineProperty(Element.prototype, 'scrollTo', {
        configurable: true,
        value: vi.fn(),
      });
      // jsdom plays nothing: the player asks the element, and reads a promise back.
      HTMLMediaElement.prototype.play = vi.fn(() => Promise.resolve());
      HTMLMediaElement.prototype.pause = vi.fn();
    });
    afterAll(() => {
      delete (Element.prototype as Partial<Element>).scrollTo;
    });

    const commented = (): LoadedPostDetail => ({
      ...body('1'),
      comments: [
        comment(1, {
          mediaBlocks: [
            { type: 'image', url: 'https://e.com/c1.jpg' },
            { type: 'image', url: 'https://e.com/c2.jpg' },
            { type: 'video', url: 'https://e.com/c.mp4', thumbnailUrl: 'https://e.com/c.jpg' },
          ],
        }),
      ],
    });
    const dialog = (name: string) =>
      document.querySelector(`[role="dialog"][aria-label="${name}"]`);
    const openSheet = async () => {
      fireEvent.click(await screen.findByRole('button', { name: /댓글 1개 모두 보기/ }));
      return (await waitFor(() => dialog('댓글 1개'))) as HTMLElement;
    };

    it("opens a comment's pictures in the viewer, on the one that was tapped", async () => {
      fake.getMergedFeed.mockResolvedValue(ok(page([post('1')])));
      fake.getPostDetail.mockResolvedValue(commented());
      render(<HomeView onOpenSettings={() => undefined} />);
      const sheet = await openSheet();

      fireEvent.click(within(sheet).getByRole('button', { name: '댓글러의 댓글 이미지 2' }));

      const viewer = (await waitFor(() => dialog('이미지 보기'))) as HTMLElement;
      expect(within(viewer).getByRole('status', { name: '이미지 2 / 2' })).toBeTruthy();
      // Two overlays, two entries: Back takes the viewer first and the sheet stays.
      await act(async () => {
        window.history.back();
        await waitFor(() => expect(dialog('이미지 보기')).toBeNull());
      });
      expect(dialog('댓글 1개')).toBeTruthy();
    });

    it("opens a comment's video full screen, playing at once, and Back closes it before the sheet", async () => {
      fake.getMergedFeed.mockResolvedValue(ok(page([post('1')])));
      fake.getPostDetail.mockResolvedValue(commented());
      render(<HomeView onOpenSettings={() => undefined} />);
      const sheet = await openSheet();

      fireEvent.click(within(sheet).getByRole('button', { name: '댓글러의 댓글 동영상' }));

      const viewer = (await waitFor(() => dialog('동영상 보기'))) as HTMLElement;
      expect(within(viewer).getByRole('button', { name: '닫기' })).toBeTruthy();
      await waitFor(() => expect(HTMLMediaElement.prototype.play).toHaveBeenCalled());
      // The modules are loaded again for each test: read the notifier the screen uses.
      const { feedVideoPlaybackNotifier } =
        await import('../../src/provider/feed_video_playback_provider');
      expect(feedVideoPlaybackNotifier().getState()).toBe('humoruniv:1#-1');

      await act(async () => {
        window.history.back();
        await waitFor(() => expect(dialog('동영상 보기')).toBeNull());
      });
      expect(dialog('댓글 1개')).toBeTruthy();
    });
  });
});
