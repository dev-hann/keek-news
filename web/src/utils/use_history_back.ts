import { useCallback, useEffect, useRef, useState } from 'react';

/** Ids handed out to overlays: an entry of the history says which overlay put it there. */
let lastId = 0;

/** True while a `back()` sent from here has not landed. */
let travelling = false;

/** Overlays gone from the page whose entry is still in the history. */
const toLeave = new Set<number>();

/** The overlay whose entry the `back()` on its way is leaving. */
let leaving: number | null = null;

/** The overlay whose entry `state` is; null for the entry of a page. */
function overlayId(state: unknown): number | null {
  if (typeof state !== 'object' || state === null) return null;
  const { overlay, id } = state as { overlay?: unknown; id?: unknown };
  return overlay === true && typeof id === 'number' ? id : null;
}

/** Steps back once. Nothing else of ours moves the history until that has landed. */
function goBack(): void {
  travelling = true;
  window.history.back();
}

/** Wherever the history lands, ours or the browser's doing: the entry left is gone for good. */
function onLanded(): void {
  travelling = false;
  if (leaving !== null) {
    toLeave.delete(leaving);
    leaving = null;
  }
  takeOffCurrent();
}

/**
 * Leaves the entry of an overlay that is gone, when that entry is the
 * current one. Under an overlay still shown, it waits for that to leave.
 */
function takeOffCurrent(): void {
  // Never while a traversal is on its way: the browser may drop the second.
  if (travelling) return;
  const id = overlayId(window.history.state);
  if (id === null || !toLeave.has(id)) return;
  leaving = id;
  goBack();
}

/**
 * Takes the entry of overlay `id` off the history: at once when it is the
 * current one, and otherwise once the overlays above it have left.
 */
function leave(id: number): void {
  toLeave.add(id);
  takeOffCurrent();
}

if (typeof window !== 'undefined') {
  window.addEventListener('popstate', onLanded);
}

/**
 * Gives an overlay one entry of the browser history, so that system Back
 * closes the overlay before it can leave the page. Returns the way to close
 * the overlay from its own UI: it leaves that entry the same way, with
 * `history.back()`, and `onClose` runs once the entry is gone, whoever took
 * it off.
 *
 * Overlays can sit one over another: an overlay closes when Back lands on
 * any entry but its own, and stays when an overlay above it closes. The
 * entry keeps the address of the page, so a router that picks the page by
 * path is not moved.
 */
export function useHistoryBack(open: boolean, onClose: () => void): () => void {
  const [id] = useState(() => lastId++);
  const close = useRef(onClose);
  useEffect(() => {
    close.current = onClose;
  });

  // True while our entry is in the history: we are on it, or waiting for the history to step off it.
  const hasEntry = useRef(false);
  const showing = useRef(false);

  useEffect(() => {
    if (!open) return;
    showing.current = true;

    const onPopState = (event: PopStateEvent) => {
      // On our own entry: an overlay above us left.
      if (overlayId(event.state) === id) return;
      // On the entry of the page, or of an overlay under us: ours is gone.
      hasEntry.current = false;
      close.current();
    };
    const show = () => {
      // A traversal is on its way: a push now would be dropped by the browser.
      if (travelling) {
        window.addEventListener('popstate', show, { once: true });
        return;
      }
      if (!hasEntry.current) {
        window.history.pushState({ overlay: true, id }, '', window.location.pathname);
        hasEntry.current = true;
      }
      window.addEventListener('popstate', onPopState);
    };
    show();

    return () => {
      showing.current = false;
      window.removeEventListener('popstate', show);
      window.removeEventListener('popstate', onPopState);
      // A moment later, not now: an effect that runs again at once keeps the
      // entry (React StrictMode and Fast Refresh start one that way).
      queueMicrotask(() => {
        if (showing.current || !hasEntry.current) return;
        hasEntry.current = false;
        leave(id);
      });
    };
  }, [open, id]);

  return useCallback(() => {
    // Asked again while leaving, or after Back took the entry: one entry, one request.
    if (!hasEntry.current) return;
    leave(id);
  }, [id]);
}
