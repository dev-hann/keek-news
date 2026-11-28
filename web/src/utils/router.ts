import { useSyncExternalStore } from 'react';

const listeners = new Set<() => void>();
/** Where each page was scrolled when the app left it by a tap, so that Back returns to the same place. */
const scrollPositions = new Map<string, number>();

function currentPath(): string {
  return window.location.pathname;
}

function notify(): void {
  listeners.forEach((listener) => listener());
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

if (typeof window !== 'undefined') {
  // The app puts every page at its own scroll offset itself.
  window.history.scrollRestoration = 'manual';
  window.addEventListener('popstate', notify);
}

/** Where `path` was scrolled when the app left it by a tap, if it was. */
export function scrollPositionOf(path: string): number | undefined {
  return scrollPositions.get(path);
}

/** Opens `to`. The page it leaves stays in the history, so Back returns to it where it was. */
export function navigate(to: string): void {
  if (currentPath() === to) return;
  scrollPositions.set(currentPath(), window.scrollY);
  window.history.pushState(null, '', to);
  notify();
}

/** The path of the page shown. */
export function usePathname(): string {
  return useSyncExternalStore(subscribe, currentPath, currentPath);
}

export const homePath = '/';
export const settingsPath = '/settings';
export const relayCheckPath = '/relay-check';
