// @vitest-environment jsdom
import { act, fireEvent, render, screen, within } from '@testing-library/react';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { BlockedImage } from '../../src/model/blocked_image';
import { StateNotifier, useNotifierState } from '../../src/provider/state_notifier';

/** The images the screen counts: the test fills the list, and can change it. */
class Blocklist extends StateNotifier<BlockedImage[]> {
  constructor(images: BlockedImage[] = []) {
    super(images);
  }

  set(images: BlockedImage[]): void {
    this.state = images;
  }
}

const blocked = (url: string): BlockedImage => ({ url, blockedAt: new Date(2026, 10, 27) });

let blocklist: Blocklist;

/** Serves a second community for a test: the app gets it the way a real one would, through the registry. */
async function serveTwoCommunities(): Promise<void> {
  vi.resetModules();
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

/** The screen over `blocked` images. Call it after the modules were reset. */
async function loadSettings(
  blocked: BlockedImage[] = []
): Promise<typeof import('../../src/pages/settings_view')> {
  blocklist = new Blocklist(blocked);
  vi.doMock('../../src/provider/blocked_images_provider', () => ({
    useBlockedImages: () => useNotifierState(blocklist),
  }));
  return import('../../src/pages/settings_view');
}

function show(
  SettingsView: typeof import('../../src/pages/settings_view').SettingsView,
  on: { onBack?: () => void; onOpenBookmarks?: () => void; onOpenBlockedImages?: () => void } = {}
) {
  return render(
    <SettingsView
      onBack={on.onBack ?? (() => undefined)}
      onOpenBookmarks={on.onOpenBookmarks ?? (() => undefined)}
      onOpenBlockedImages={on.onOpenBlockedImages ?? (() => undefined)}
    />
  );
}

/** The group of `title`, as the rows of one surface. */
function group(title: string): HTMLElement {
  return screen.getByRole('heading', { level: 2, name: title }).closest('section') as HTMLElement;
}

const groupTitles = (): (string | null)[] =>
  screen.getAllByRole('heading', { level: 2 }).map((heading) => heading.textContent);

describe('SettingsView', () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  it('has a title and a way back', async () => {
    vi.resetModules();
    const { SettingsView } = await loadSettings();
    const onBack = vi.fn();

    show(SettingsView, { onBack });
    fireEvent.click(screen.getByRole('button', { name: '뒤로' }));

    expect(screen.getByRole('heading', { level: 1, name: '설정' })).toBeTruthy();
    expect(onBack).toHaveBeenCalledTimes(1);
  });

  it('lists the communities the app serves, by name', async () => {
    vi.resetModules();
    const { SettingsView } = await loadSettings();

    show(SettingsView);

    expect(screen.getByText('웃긴대학')).toBeTruthy();
    expect(screen.queryByText('DogDrip')).toBeNull();
  });

  it('does not let the last community on be switched off', async () => {
    vi.resetModules();
    const { SettingsView } = await loadSettings();

    show(SettingsView);
    const switch_ = screen.getByRole('switch', { name: '웃긴대학 보기' });

    expect(switch_.getAttribute('aria-checked')).toBe('true');
    expect(switch_).toHaveProperty('disabled', true);
  });

  it('switches a community off and remembers it, with another one still on', async () => {
    await serveTwoCommunities();
    const { SettingsView } = await loadSettings();

    show(SettingsView);
    const dogdrip = screen.getByRole('switch', { name: 'DogDrip 보기' });
    expect(dogdrip).toHaveProperty('disabled', false);

    fireEvent.click(dogdrip);

    expect(dogdrip.getAttribute('aria-checked')).toBe('false');
    expect(JSON.parse(window.localStorage.getItem('enabled_communities') ?? 'null')).toEqual([
      'humoruniv',
    ]);
    vi.doUnmock('../../src/model/community');
  });

  it('shows the version and where the source code is', async () => {
    vi.resetModules();
    const { SettingsView } = await loadSettings();

    show(SettingsView);

    expect(screen.getByText(`v${__APP_VERSION__}`)).toBeTruthy();
    const source = screen.getByRole('link', { name: /소스 코드/ });
    expect(source).toHaveProperty('href', 'https://github.com/dev-hann/keek-news');
    expect(source).toHaveProperty('target', '_blank');
  });

  it('asks about a new version each time the settings open, and gives the version row its taps', async () => {
    vi.resetModules();
    const updater = {
      enter: vi.fn(),
      download: vi.fn(),
      cancel: vi.fn(),
      retry: vi.fn(),
      install: vi.fn(async () => undefined),
      openInstallSettings: vi.fn(async () => undefined),
    };
    vi.doMock('../../src/provider/update_provider', () => ({
      updateNotifier: () => updater,
      useUpdate: () => ({
        status: 'available',
        version: '4.0.0',
        support: 'native',
        release: {
          tag: 'v4.1.0',
          version: '4.1.0',
          pageUrl: 'https://github.com/dev-hann/keek-news/releases/tag/v4.1.0',
          apkUrl: 'https://github.com/dev-hann/keek-news/releases/download/v4.1.0/keek-news.apk',
        },
        percent: null,
      }),
    }));
    const { SettingsView } = await loadSettings();

    const first = show(SettingsView);
    expect(updater.enter).toHaveBeenCalledTimes(1);
    fireEvent.click(screen.getByRole('button', { name: '업데이트' }));
    expect(updater.download).toHaveBeenCalledTimes(1);

    first.unmount();
    show(SettingsView);
    expect(updater.enter).toHaveBeenCalledTimes(2);
    vi.doUnmock('../../src/provider/update_provider');
  });

  it('groups the settings as 저장함 and 미디어 & 데이터 between the communities and 정보', async () => {
    vi.resetModules();
    const { SettingsView } = await loadSettings();

    show(SettingsView);

    expect(groupTitles()).toEqual(['커뮤니티', '저장함', '미디어 & 데이터', '정보']);
    // The image cache is of the Flutter app: the web app has none.
    expect(screen.queryByText('이미지 캐시')).toBeNull();
    // The icon of each row only decorates: the row is named by its title.
    for (const title of ['저장한 게시물', '차단된 이미지']) {
      const row = screen.getByRole('button', { name: new RegExp(`^${title}`) });
      expect(within(row).getByText(title)).toBeTruthy();
      expect(row.querySelector('[aria-hidden="true"] svg')).not.toBeNull();
    }
  });

  it('opens the saved posts and the blocked images from their rows', async () => {
    vi.resetModules();
    const { SettingsView } = await loadSettings();
    const onOpenBookmarks = vi.fn();
    const onOpenBlockedImages = vi.fn();

    show(SettingsView, { onOpenBookmarks, onOpenBlockedImages });

    fireEvent.click(within(group('저장함')).getByRole('button', { name: '저장한 게시물' }));
    expect(onOpenBookmarks).toHaveBeenCalledTimes(1);
    expect(onOpenBlockedImages).not.toHaveBeenCalled();

    fireEvent.click(
      within(group('미디어 & 데이터')).getByRole('button', { name: /^차단된 이미지/ })
    );
    expect(onOpenBlockedImages).toHaveBeenCalledTimes(1);
    expect(onOpenBookmarks).toHaveBeenCalledTimes(1);
  });

  it('counts the blocked images, as the list stands', async () => {
    vi.resetModules();
    const { SettingsView } = await loadSettings([blocked('https://e.com/a.jpg')]);
    show(SettingsView);

    const row = (): HTMLElement => screen.getByRole('button', { name: /^차단된 이미지/ });
    expect(within(row()).getByText('1개')).toBeTruthy();

    act(() => blocklist.set([blocked('https://e.com/a.jpg'), blocked('https://e.com/b.jpg')]));
    expect(within(row()).getByText('2개')).toBeTruthy();

    act(() => blocklist.set([]));
    expect(within(row()).getByText('0개')).toBeTruthy();
  });
});
