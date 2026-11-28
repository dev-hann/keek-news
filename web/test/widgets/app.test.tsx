// @vitest-environment jsdom
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { CommunityId } from '../../src/model/community';
import type { MergedPage } from '../../src/model/merged_feed';
import { blockedImagesPath, bookmarksPath, homePath, settingsPath } from '../../src/utils/router';

const emptyPage = (): MergedPage => ({ items: [], next: null, failedSources: new Set() });

/** The use case the pages see: the one community that is on, with an empty feed. */
const fake = {
  getMergedFeed: vi.fn(async () => ({ ok: true, value: emptyPage() })),
  getPostDetail: vi.fn(),
  getEnabledCommunities: vi.fn(() => new Set<CommunityId>(['humoruniv'])),
  canDisableCommunity: vi.fn(() => false),
  toggleCommunity: vi.fn(),
};

const toast = { success: vi.fn(), error: vi.fn() };

let App: typeof import('../../src/app').App;

/** The app over nothing saved and nothing blocked. */
async function loadApp(): Promise<void> {
  vi.resetModules();
  vi.doMock('../../src/service/service_locator', () => ({ feedUseCase: () => fake }));
  vi.doMock('../../src/provider/bookmark_provider', () => ({
    bookmarkNotifier: () => ({ isBookmarked: () => false, toggle: async () => false }),
    useBookmarks: () => [],
  }));
  vi.doMock('../../src/provider/blocked_images_provider', () => ({
    blockedImagesNotifier: () => ({ unblock: async () => ({ ok: true, value: undefined }) }),
    useBlockedImages: () => [],
  }));
  vi.doMock('sonner', () => ({ toast, Toaster: () => null }));
  ({ App } = await import('../../src/app'));
}

describe('App', () => {
  beforeEach(async () => {
    window.history.replaceState(null, '', homePath);
    window.scrollTo = vi.fn();
    window.matchMedia = vi.fn().mockReturnValue({ matches: false }) as never;
    await loadApp();
  });

  afterEach(() => {
    // The next test starts at the feed, wherever this one left the history.
    window.history.replaceState(null, '', homePath);
  });

  it('shows 저장함 when it is opened at /bookmarks', () => {
    window.history.replaceState(null, '', bookmarksPath);
    render(<App />);

    expect(screen.getByRole('heading', { level: 1, name: '저장함' })).toBeTruthy();
    expect(screen.getByText('저장한 게시물이 없어요')).toBeTruthy();
  });

  it('shows 차단된 이미지 when it is opened at /blocked-images', () => {
    window.history.replaceState(null, '', blockedImagesPath);
    render(<App />);

    expect(screen.getByRole('heading', { level: 1, name: '차단된 이미지' })).toBeTruthy();
    expect(screen.getByText('차단된 이미지가 없어요')).toBeTruthy();
  });

  it('opens 저장함 from its settings row at the top of the page, and 뒤로 returns to the settings', async () => {
    window.history.replaceState(null, '', settingsPath);
    render(<App />);

    fireEvent.click(screen.getByRole('button', { name: '저장한 게시물' }));

    expect(window.location.pathname).toBe(bookmarksPath);
    expect(screen.getByRole('heading', { level: 1, name: '저장함' })).toBeTruthy();
    expect(window.scrollTo).toHaveBeenLastCalledWith(0, 0);

    fireEvent.click(screen.getByRole('button', { name: '뒤로' }));

    // jsdom leaves the history entry a tick later.
    await waitFor(() => expect(window.location.pathname).toBe(settingsPath));
    expect(screen.getByRole('heading', { level: 1, name: '설정' })).toBeTruthy();
  });

  it('opens 차단된 이미지 from its settings row, and 뒤로 returns to the settings', async () => {
    window.history.replaceState(null, '', settingsPath);
    render(<App />);

    fireEvent.click(screen.getByRole('button', { name: /^차단된 이미지/ }));

    expect(window.location.pathname).toBe(blockedImagesPath);
    expect(screen.getByRole('heading', { level: 1, name: '차단된 이미지' })).toBeTruthy();

    fireEvent.click(screen.getByRole('button', { name: '뒤로' }));

    await waitFor(() => expect(window.location.pathname).toBe(settingsPath));
    expect(screen.getByRole('heading', { level: 1, name: '설정' })).toBeTruthy();
  });

  it('goes from the feed to the saved posts, and all the way back', async () => {
    render(<App />);
    expect(screen.getByRole('heading', { level: 1, name: '웃긴대학' })).toBeTruthy();

    fireEvent.click(screen.getByRole('button', { name: '설정' }));
    expect(window.location.pathname).toBe(settingsPath);

    fireEvent.click(screen.getByRole('button', { name: '저장한 게시물' }));
    expect(window.location.pathname).toBe(bookmarksPath);

    fireEvent.click(screen.getByRole('button', { name: '뒤로' }));
    await waitFor(() => expect(window.location.pathname).toBe(settingsPath));
    expect(screen.getByRole('heading', { level: 1, name: '설정' })).toBeTruthy();

    fireEvent.click(screen.getByRole('button', { name: '뒤로' }));
    await waitFor(() => expect(window.location.pathname).toBe(homePath));
    expect(screen.getByRole('heading', { level: 1, name: '웃긴대학' })).toBeTruthy();
  });
});
