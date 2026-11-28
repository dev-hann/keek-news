// @vitest-environment jsdom
import { fireEvent, render, screen } from '@testing-library/react';
import { beforeEach, describe, expect, it, vi } from 'vitest';

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

async function loadSettings(): Promise<typeof import('../../src/pages/settings_view')> {
  return import('../../src/pages/settings_view');
}

describe('SettingsView', () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  it('has a title and a way back', async () => {
    vi.resetModules();
    const { SettingsView } = await loadSettings();
    const onBack = vi.fn();

    render(<SettingsView onBack={onBack} />);
    fireEvent.click(screen.getByRole('button', { name: '뒤로' }));

    expect(screen.getByRole('heading', { level: 1, name: '설정' })).toBeTruthy();
    expect(onBack).toHaveBeenCalledTimes(1);
  });

  it('lists the communities the app serves, by name', async () => {
    vi.resetModules();
    const { SettingsView } = await loadSettings();

    render(<SettingsView onBack={() => undefined} />);

    expect(screen.getByText('웃긴대학')).toBeTruthy();
    expect(screen.queryByText('DogDrip')).toBeNull();
  });

  it('does not let the last community on be switched off', async () => {
    vi.resetModules();
    const { SettingsView } = await loadSettings();

    render(<SettingsView onBack={() => undefined} />);
    const switch_ = screen.getByRole('switch', { name: '웃긴대학 보기' });

    expect(switch_.getAttribute('aria-checked')).toBe('true');
    expect(switch_).toHaveProperty('disabled', true);
  });

  it('switches a community off and remembers it, with another one still on', async () => {
    await serveTwoCommunities();
    const { SettingsView } = await loadSettings();

    render(<SettingsView onBack={() => undefined} />);
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

    render(<SettingsView onBack={() => undefined} />);

    expect(screen.getByText(`v${__APP_VERSION__}`)).toBeTruthy();
    const source = screen.getByRole('link', { name: /소스 코드/ });
    expect(source).toHaveProperty('href', 'https://github.com/dev-hann/keek-news');
    expect(source).toHaveProperty('target', '_blank');
  });
});
