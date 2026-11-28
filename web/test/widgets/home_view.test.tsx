// @vitest-environment jsdom
import { act, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
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
  vi.doMock('../../src/service/service_locator', () => ({ feedUseCase: () => fake }));
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

  it('refreshes without the skeleton and keeps the posts until the new page has arrived', async () => {
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
    fireEvent.click(screen.getByRole('button', { name: '새로고침' }));

    expect(screen.getByText('제목 1')).toBeTruthy();
    expect(screen.queryByRole('progressbar', { name: '게시글 불러오는 중' })).toBeNull();
    expect(screen.getByRole('button', { name: '새로고침' })).toHaveProperty('disabled', true);

    await act(async () => arrive(page([post('2')])));
    expect(await screen.findByText('제목 2')).toBeTruthy();
    expect(screen.queryByText('제목 1')).toBeNull();
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
});
