// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { act } from 'react';
import { createRoot } from 'react-dom/client';
import { waitFor } from '@testing-library/react';
import {
  homePath,
  navigate,
  scrollPositionOf,
  settingsPath,
  usePathname,
} from '../../src/utils/router';

function Path() {
  return <p data-testid="path">{usePathname()}</p>;
}

describe('router', () => {
  beforeEach(() => {
    window.history.replaceState(null, '', homePath);
  });

  afterEach(() => {
    window.history.replaceState(null, '', homePath);
  });

  it('adds the page to the history and tells the app', async () => {
    const host = document.createElement('div');
    const root = createRoot(host);
    await act(() => root.render(<Path />));
    expect(host.textContent).toBe(homePath);

    await act(() => navigate(settingsPath));

    expect(host.textContent).toBe(settingsPath);
    expect(window.location.pathname).toBe(settingsPath);
    await act(() => root.unmount());
  });

  it('going to the page that is shown does nothing', () => {
    const before = window.history.length;

    navigate(settingsPath);
    navigate(settingsPath);

    expect(window.history.length).toBe(before + 1);
  });

  it('remembers where a page was scrolled when the app leaves it', () => {
    // jsdom lays nothing out: say where the page is instead of scrolling it.
    const scrollY = vi.spyOn(window, 'scrollY', 'get');
    scrollY.mockReturnValue(0);
    navigate(settingsPath);
    scrollY.mockReturnValue(480);

    navigate(homePath);

    expect(scrollPositionOf(settingsPath)).toBe(480);
    expect(scrollPositionOf(homePath)).toBe(0);
    scrollY.mockRestore();
  });

  it('follows Back', async () => {
    const host = document.createElement('div');
    const root = createRoot(host);
    await act(() => root.render(<Path />));
    await act(() => navigate(settingsPath));

    // jsdom leaves the history entry a tick later, and under load more than one tick.
    await act(async () => {
      window.history.back();
      await waitFor(() => expect(host.textContent).toBe(homePath));
    });

    expect(host.textContent).toBe(homePath);
    await act(() => root.unmount());
  });
});
