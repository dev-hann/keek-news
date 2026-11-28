// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen } from '@testing-library/react';
import { StrictMode, useState } from 'react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { useHistoryBack } from '../../src/utils/use_history_back';

/** The state of the page's own entry, to tell it from an overlay's. */
const HOME = { page: 'home' };

/** The overlay whose entry the history is on; null for the entry of a page. */
function overlayIdOf(state: unknown): number | null {
  return typeof state === 'object' && state !== null && 'id' in state ? (state.id as number) : null;
}

/** An entry of an overlay: marked as one, and saying which. */
const AN_OVERLAY_ENTRY = { overlay: true, id: expect.any(Number) as number };

/** Shown while `open` says so: the test closes it. */
function Overlay({
  open,
  onClose,
  name = 'overlay',
}: {
  open: boolean;
  onClose: () => void;
  name?: string;
}) {
  const requestClose = useHistoryBack(open, onClose);
  return <button onClick={requestClose}>close the {name}</button>;
}

/** Closes itself when asked, the way a page does when it sets its `open` to false. */
function SelfClosingOverlay({
  onClose,
  name = 'overlay',
}: {
  onClose?: () => void;
  name?: string;
}) {
  const [open, setOpen] = useState(true);
  const requestClose = useHistoryBack(open, () => {
    onClose?.();
    setOpen(false);
  });
  return <button onClick={requestClose}>close the {name}</button>;
}

/** A media sheet over the image viewer it was opened from. Each asks the page to close it. */
function ViewerAndSheet({
  onViewerClose,
  onSheetClose,
}: {
  onViewerClose?: () => void;
  onSheetClose?: () => void;
}) {
  const [viewer, setViewer] = useState(false);
  const [sheet, setSheet] = useState(false);
  return (
    <>
      <button onClick={() => setViewer(true)}>open the viewer</button>
      <button onClick={() => setSheet(true)}>open the sheet</button>
      <Overlay
        name="viewer"
        open={viewer}
        onClose={() => {
          setViewer(false);
          onViewerClose?.();
        }}
      />
      <Overlay
        name="sheet"
        open={sheet}
        onClose={() => {
          setSheet(false);
          onSheetClose?.();
        }}
      />
    </>
  );
}

/** jsdom leaves a history entry a task or two later: one such task. */
async function tick(): Promise<void> {
  await act(async () => {
    await new Promise((resolve) => setTimeout(resolve, 0));
  });
}

async function until(done: () => boolean): Promise<void> {
  for (let i = 0; i < 10 && !done(); i++) await tick();
}

/** Outlasts whatever traversal a closing asked for. */
async function settle(): Promise<void> {
  for (let i = 0; i < 3; i++) await tick();
}

/** The page shown is the last entry: a push drops what a test before left in front of it. */
function startAtHome(): void {
  window.history.pushState(HOME, '', '/');
}

/** Puts a page in the history before the one shown, as the app does when it opens one. */
function pageBehind(): void {
  window.history.pushState({ page: 'settings' }, '', '/settings');
  startAtHome();
}

/** Notes, for each `popstate`, where the history landed: an overlay's id, or null for a page. */
function recordLandings(): (number | null)[] {
  const landings: (number | null)[] = [];
  window.addEventListener('popstate', () => landings.push(overlayIdOf(window.history.state)));
  return landings;
}

const onThePageEntry = () => overlayIdOf(window.history.state) === null;

describe('useHistoryBack', () => {
  beforeEach(startAtHome);

  afterEach(async () => {
    // Nothing of this test may traverse the history in the next one.
    cleanup();
    await settle();
    startAtHome();
    vi.restoreAllMocks();
  });

  it('puts one entry on the history when the overlay opens, at the address of the page, marked as its own', () => {
    const before = window.history.length;
    const onClose = vi.fn();

    render(<Overlay open onClose={onClose} />);

    expect(window.history.length).toBe(before + 1);
    expect(window.history.state).toMatchObject(AN_OVERLAY_ENTRY);
    expect(window.location.pathname).toBe('/');
    expect(onClose).not.toHaveBeenCalled();
  });

  it('puts nothing on the history while the overlay is closed', () => {
    const before = window.history.length;

    render(<Overlay open={false} onClose={() => undefined} />);

    expect(window.history.length).toBe(before);
    expect(window.history.state).toEqual(HOME);
  });

  it('gives each overlay an entry of its own: two open, one over the other', () => {
    const before = window.history.length;
    render(<ViewerAndSheet />);

    fireEvent.click(screen.getByRole('button', { name: 'open the viewer' }));
    const viewerEntry = overlayIdOf(window.history.state);
    fireEvent.click(screen.getByRole('button', { name: 'open the sheet' }));

    expect(window.history.length).toBe(before + 2);
    expect(overlayIdOf(window.history.state)).not.toBe(viewerEntry);
    expect(window.location.pathname).toBe('/');
  });

  it('system Back takes the entry off and closes the overlay once', async () => {
    const before = window.history.length;
    const onClose = vi.fn();
    render(<SelfClosingOverlay onClose={onClose} />);

    act(() => window.history.back());
    await until(() => onClose.mock.calls.length > 0);

    expect(onClose).toHaveBeenCalledTimes(1);
    expect(window.history.state).toEqual(HOME);
    expect(window.location.pathname).toBe('/');
    // Left by Back, the entry is in front of the page, not behind it: the next Back leaves the page.
    expect(window.history.length).toBe(before + 1);
    act(() => window.history.back());
    await until(() => window.location.pathname !== '/');
    expect(onClose).toHaveBeenCalledTimes(1);
  });

  it('closing from the UI takes the same entry off the same way, then closes once', async () => {
    pageBehind();
    const onClose = vi.fn();
    render(<SelfClosingOverlay onClose={onClose} />);
    const push = vi.spyOn(window.history, 'pushState');

    fireEvent.click(screen.getByRole('button', { name: 'close the overlay' }));
    expect(onClose).not.toHaveBeenCalled();

    await until(() => onClose.mock.calls.length > 0);

    expect(onClose).toHaveBeenCalledTimes(1);
    expect(window.history.state).toEqual(HOME);
    expect(window.location.pathname).toBe('/');
    expect(push).not.toHaveBeenCalled();

    // The entry of the overlay is not in the way of the page behind.
    act(() => window.history.back());
    await until(() => window.location.pathname === '/settings');
    expect(onClose).toHaveBeenCalledTimes(1);
  });

  it('asked to close twice, leaves the one entry and not the page', async () => {
    pageBehind();
    const onClose = vi.fn();
    const back = vi.spyOn(window.history, 'back');
    render(<SelfClosingOverlay onClose={onClose} />);
    const close = screen.getByRole('button', { name: 'close the overlay' });

    fireEvent.click(close);
    fireEvent.click(close);
    await until(() => onClose.mock.calls.length > 0);
    await settle();

    expect(back).toHaveBeenCalledTimes(1);
    expect(onClose).toHaveBeenCalledTimes(1);
    expect(window.history.state).toEqual(HOME);
    expect(window.location.pathname).toBe('/');
  });

  it('after Back took the entry, a late request to close takes nothing more', async () => {
    pageBehind();
    const onClose = vi.fn();
    // Still shown: a page renders its closing a moment after it is asked to.
    render(<Overlay open onClose={onClose} />);
    act(() => window.history.back());
    await until(() => onClose.mock.calls.length > 0);

    fireEvent.click(screen.getByRole('button', { name: 'close the overlay' }));
    await settle();

    expect(window.history.state).toEqual(HOME);
    expect(window.location.pathname).toBe('/');
    expect(onClose).toHaveBeenCalledTimes(1);
  });

  it('closed by the page itself, the entry goes too', async () => {
    const onClose = vi.fn();
    const { rerender } = render(<Overlay open onClose={onClose} />);

    rerender(<Overlay open={false} onClose={onClose} />);
    await until(onThePageEntry);

    expect(window.history.state).toEqual(HOME);
    expect(window.location.pathname).toBe('/');
    expect(onClose).not.toHaveBeenCalled();
  });

  it('closed by the page itself and opened again once that has landed, puts one entry again', async () => {
    const before = window.history.length;
    const onClose = vi.fn();
    const { rerender } = render(<Overlay open onClose={onClose} />);
    rerender(<Overlay open={false} onClose={onClose} />);
    await until(onThePageEntry);

    rerender(<Overlay open onClose={onClose} />);

    expect(window.history.length).toBe(before + 1);
    expect(window.history.state).toMatchObject(AN_OVERLAY_ENTRY);
  });

  it('opened again before the leave it asked for has landed, puts the entry back only once that has landed', async () => {
    const before = window.history.length;
    const onClose = vi.fn();
    const push = vi.spyOn(window.history, 'pushState');
    const pop = vi.fn();
    window.addEventListener('popstate', pop);
    const { rerender } = render(<Overlay open onClose={onClose} />);
    rerender(<Overlay open={false} onClose={onClose} />);
    // The leave is asked for a microtask later; jsdom lands it a task or two after that.
    await act(async () => {
      await Promise.resolve();
    });
    rerender(<Overlay open onClose={onClose} />);
    // A push now would be dropped by the browser.
    expect(push).toHaveBeenCalledTimes(1);

    await until(() => push.mock.calls.length > 1);

    // Only once the leave has landed.
    expect(pop.mock.invocationCallOrder[0]).toBeLessThan(push.mock.invocationCallOrder[1]);
    expect(window.history.length).toBe(before + 1);
    expect(window.history.state).toMatchObject(AN_OVERLAY_ENTRY);
    expect(onClose).not.toHaveBeenCalled();
  });

  it('opened again before the leave has landed and closed again before it has: nothing is pushed', async () => {
    const onClose = vi.fn();
    const push = vi.spyOn(window.history, 'pushState');
    const { rerender } = render(<Overlay open onClose={onClose} />);
    rerender(<Overlay open={false} onClose={onClose} />);
    await act(async () => {
      await Promise.resolve();
    });
    rerender(<Overlay open onClose={onClose} />);
    rerender(<Overlay open={false} onClose={onClose} />);
    await settle();

    expect(push).toHaveBeenCalledTimes(1);
    expect(window.history.state).toEqual(HOME);
    expect(onClose).not.toHaveBeenCalled();
  });

  it('taken off the page while the UI was closing it, and opened again at once: one `back()`, then one entry again', async () => {
    const before = window.history.length;
    const first = vi.fn();
    const second = vi.fn();
    const push = vi.spyOn(window.history, 'pushState');
    const back = vi.spyOn(window.history, 'back');
    const pop = vi.fn();
    window.addEventListener('popstate', pop);
    const { unmount } = render(<Overlay open onClose={first} />);
    fireEvent.click(screen.getByRole('button', { name: 'close the overlay' }));

    unmount();
    render(<Overlay open onClose={second} />);
    await until(() => push.mock.calls.length > 1);

    // Going off the page asked for no second `back()`: that one would have taken the page's own entry.
    expect(back).toHaveBeenCalledTimes(1);
    expect(pop.mock.invocationCallOrder[0]).toBeLessThan(push.mock.invocationCallOrder[1]);
    expect(window.history.length).toBe(before + 1);
    expect(first).not.toHaveBeenCalled();
    expect(second).not.toHaveBeenCalled();
  });

  it('taken off the page while open, the entry goes too', async () => {
    const { unmount } = render(<Overlay open onClose={() => undefined} />);

    unmount();
    await until(onThePageEntry);

    expect(window.history.state).toEqual(HOME);
  });

  it('mounted open under StrictMode, where the effect runs twice, still puts one entry', async () => {
    const before = window.history.length;

    render(
      <StrictMode>
        <Overlay open onClose={() => undefined} />
      </StrictMode>
    );
    await settle();

    expect(window.history.length).toBe(before + 1);
    expect(window.history.state).toMatchObject(AN_OVERLAY_ENTRY);
  });

  it('closed and opened again at once keeps its entry: nothing is popped and nothing pushed', async () => {
    const before = window.history.length;
    const onClose = vi.fn();
    const push = vi.spyOn(window.history, 'pushState');
    const { rerender } = render(<Overlay open onClose={onClose} />);

    rerender(<Overlay open={false} onClose={onClose} />);
    rerender(<Overlay open onClose={onClose} />);
    await settle();

    expect(push).toHaveBeenCalledTimes(1);
    expect(window.history.state).toMatchObject(AN_OVERLAY_ENTRY);
    expect(onClose).not.toHaveBeenCalled();
    expect(window.history.length).toBe(before + 1);
  });

  it('opened again after it was closed, puts one entry again', async () => {
    const before = window.history.length;
    const onClose = vi.fn();
    const { rerender } = render(<SelfClosingOverlay onClose={onClose} />);
    fireEvent.click(screen.getByRole('button', { name: 'close the overlay' }));
    await until(() => onClose.mock.calls.length > 0);
    rerender(<SelfClosingOverlay key="again" onClose={onClose} />);

    expect(window.history.length).toBe(before + 1);
    expect(window.history.state).toMatchObject(AN_OVERLAY_ENTRY);
  });

  it('a popstate onto the entry of the overlay itself does not close it', () => {
    const onClose = vi.fn();
    render(<Overlay open onClose={onClose} />);
    const ownEntry = window.history.state;

    fireEvent(window, new PopStateEvent('popstate', { state: ownEntry }));

    expect(onClose).not.toHaveBeenCalled();
  });

  it('two overlays, one opened from inside the other: Back closes the top one only, the next Back the other, each told once', async () => {
    const before = window.history.length;
    const viewerClose = vi.fn();
    const sheetClose = vi.fn();
    render(<ViewerAndSheet onViewerClose={viewerClose} onSheetClose={sheetClose} />);
    fireEvent.click(screen.getByRole('button', { name: 'open the viewer' }));
    const viewerEntry = overlayIdOf(window.history.state);
    fireEvent.click(screen.getByRole('button', { name: 'open the sheet' }));
    expect(window.history.length).toBe(before + 2);

    act(() => window.history.back());
    await until(() => sheetClose.mock.calls.length > 0);

    expect(sheetClose).toHaveBeenCalledTimes(1);
    expect(viewerClose).not.toHaveBeenCalled();
    // The history is on the entry of the viewer, which is still shown.
    expect(overlayIdOf(window.history.state)).toBe(viewerEntry);

    act(() => window.history.back());
    await until(() => viewerClose.mock.calls.length > 0);

    expect(viewerClose).toHaveBeenCalledTimes(1);
    expect(sheetClose).toHaveBeenCalledTimes(1);
    expect(window.history.state).toEqual(HOME);
    expect(window.location.pathname).toBe('/');
  });

  it('the lower overlay is not closed by a popstate onto its own entry', () => {
    const viewerClose = vi.fn();
    const sheetClose = vi.fn();
    render(<ViewerAndSheet onViewerClose={viewerClose} onSheetClose={sheetClose} />);
    fireEvent.click(screen.getByRole('button', { name: 'open the viewer' }));
    const viewerEntry = window.history.state;
    fireEvent.click(screen.getByRole('button', { name: 'open the sheet' }));

    fireEvent(window, new PopStateEvent('popstate', { state: viewerEntry }));

    expect(viewerClose).not.toHaveBeenCalled();
    expect(sheetClose).toHaveBeenCalledTimes(1);
  });

  it('the UI closing the top overlay and, at once, the page closing the lower one: both entries come off, in order', async () => {
    const viewerClose = vi.fn();
    const sheetClose = vi.fn();
    const landings = recordLandings();
    const back = vi.spyOn(window.history, 'back');
    // The sheet closes itself when asked; the page opens and closes the viewer.
    function Page({ viewer }: { viewer: boolean }) {
      const [sheet, setSheet] = useState(false);
      return (
        <>
          <button onClick={() => setSheet(true)}>open the sheet</button>
          <Overlay name="viewer" open={viewer} onClose={viewerClose} />
          <Overlay
            name="sheet"
            open={sheet}
            onClose={() => {
              setSheet(false);
              sheetClose();
            }}
          />
        </>
      );
    }
    const { rerender } = render(<Page viewer />);
    const viewerEntry = overlayIdOf(window.history.state);
    fireEvent.click(screen.getByRole('button', { name: 'open the sheet' }));

    fireEvent.click(screen.getByRole('button', { name: 'close the sheet' }));
    // The page closes the viewer before the entry of the sheet has left.
    rerender(<Page viewer={false} />);
    await until(() => landings.length >= 1);
    await settle();

    // First the entry of the sheet went, landing on the viewer's; then that one went too.
    expect(landings).toEqual([viewerEntry, null]);
    expect(back).toHaveBeenCalledTimes(2);
    expect(sheetClose).toHaveBeenCalledTimes(1);
    // The page closed the viewer itself: the hook had nothing to tell it.
    expect(viewerClose).not.toHaveBeenCalled();
    expect(window.history.state).toEqual(HOME);
    expect(window.location.pathname).toBe('/');
  });

  it('the UI closing the top overlay and, right after, the lower one asking to close: both come off, in order, each told once', async () => {
    const viewerClose = vi.fn();
    const sheetClose = vi.fn();
    const landings = recordLandings();
    render(<ViewerAndSheet onViewerClose={viewerClose} onSheetClose={sheetClose} />);
    fireEvent.click(screen.getByRole('button', { name: 'open the viewer' }));
    const viewerEntry = overlayIdOf(window.history.state);
    fireEvent.click(screen.getByRole('button', { name: 'open the sheet' }));

    fireEvent.click(screen.getByRole('button', { name: 'close the sheet' }));
    fireEvent.click(screen.getByRole('button', { name: 'close the viewer' }));
    await until(() => viewerClose.mock.calls.length > 0);
    await settle();

    expect(landings).toEqual([viewerEntry, null]);
    expect(sheetClose).toHaveBeenCalledTimes(1);
    expect(viewerClose).toHaveBeenCalledTimes(1);
    expect(window.history.state).toEqual(HOME);
  });

  it('closed by the page both at once, both entries come off', async () => {
    const viewerClose = vi.fn();
    const sheetClose = vi.fn();
    const landings = recordLandings();
    const tree = (open: boolean) => (
      <>
        <Overlay name="viewer" open={open} onClose={viewerClose} />
        <Overlay name="sheet" open={open} onClose={sheetClose} />
      </>
    );
    const { rerender } = render(tree(true));

    rerender(tree(false));
    await until(() => landings.length >= 2);

    // Off the entry of the sheet onto the viewer's, then off that one.
    expect(landings).toEqual([expect.any(Number), null]);
    expect(window.history.state).toEqual(HOME);
    expect(viewerClose).not.toHaveBeenCalled();
    expect(sheetClose).not.toHaveBeenCalled();
  });

  it('an overlay opened while another is closing gets its entry after the popstate, not before', async () => {
    const first = vi.fn();
    const second = vi.fn();
    const push = vi.spyOn(window.history, 'pushState');
    const pop = vi.fn();
    window.addEventListener('popstate', pop);
    const tree = (secondOpen: boolean) => (
      <>
        <Overlay open onClose={first} />
        <Overlay name="second" open={secondOpen} onClose={second} />
      </>
    );
    const { rerender } = render(tree(false));
    const firstEntry = overlayIdOf(window.history.state);
    fireEvent.click(screen.getByRole('button', { name: 'close the overlay' }));

    rerender(tree(true));
    expect(push).toHaveBeenCalledTimes(1);
    await until(() => push.mock.calls.length > 1);

    expect(pop.mock.invocationCallOrder[0]).toBeLessThan(push.mock.invocationCallOrder[1]);
    expect(window.history.state).toMatchObject(AN_OVERLAY_ENTRY);
    expect(overlayIdOf(window.history.state)).not.toBe(firstEntry);
    expect(first).toHaveBeenCalledTimes(1);
    expect(second).not.toHaveBeenCalled();
  });

  it('an overlay replaced by another while open lets the new one stay, and its entry goes once that one has left', async () => {
    const first = vi.fn();
    const second = vi.fn();
    const landings = recordLandings();
    const { rerender } = render(<SelfClosingOverlay key="first" onClose={first} />);
    const firstEntry = overlayIdOf(window.history.state);

    rerender(<SelfClosingOverlay key="second" onClose={second} />);
    await settle();

    // The new overlay is shown over the old entry, which waits under it.
    expect(second).not.toHaveBeenCalled();
    const secondEntry = overlayIdOf(window.history.state);
    expect(secondEntry).not.toBe(firstEntry);

    fireEvent.click(screen.getByRole('button', { name: 'close the overlay' }));
    await until(() => second.mock.calls.length > 0);
    await until(() => landings.length >= 2);

    expect(second).toHaveBeenCalledTimes(1);
    expect(landings).toEqual([firstEntry, null]);
    expect(window.history.state).toEqual(HOME);
  });

  it('an overlay replaced by another while open: Back closes the new one and steps over the old entry at once', async () => {
    const second = vi.fn();
    const landings = recordLandings();
    const { rerender } = render(<SelfClosingOverlay key="first" onClose={() => undefined} />);
    const firstEntry = overlayIdOf(window.history.state);
    rerender(<SelfClosingOverlay key="second" onClose={second} />);
    await settle();

    act(() => window.history.back());
    await until(() => second.mock.calls.length > 0);
    await until(() => landings.length >= 2);

    expect(second).toHaveBeenCalledTimes(1);
    expect(landings).toEqual([firstEntry, null]);
    expect(window.history.state).toEqual(HOME);
  });

  it('closed by the page under an overlay still shown, the lower entry waits, and goes once that one has left', async () => {
    const viewerClose = vi.fn();
    const sheetClose = vi.fn();
    const landings = recordLandings();
    function Page({ viewer }: { viewer: boolean }) {
      const [sheet, setSheet] = useState(false);
      return (
        <>
          <button onClick={() => setSheet(true)}>open the sheet</button>
          <Overlay name="viewer" open={viewer} onClose={viewerClose} />
          <Overlay
            name="sheet"
            open={sheet}
            onClose={() => {
              setSheet(false);
              sheetClose();
            }}
          />
        </>
      );
    }
    const { rerender } = render(<Page viewer />);
    const viewerEntry = overlayIdOf(window.history.state);
    fireEvent.click(screen.getByRole('button', { name: 'open the sheet' }));
    const sheetEntry = overlayIdOf(window.history.state);

    rerender(<Page viewer={false} />);
    await settle();

    // The sheet is still shown on its own entry; the viewer's waits under it.
    expect(overlayIdOf(window.history.state)).toBe(sheetEntry);
    expect(sheetClose).not.toHaveBeenCalled();

    fireEvent.click(screen.getByRole('button', { name: 'close the sheet' }));
    await until(() => sheetClose.mock.calls.length > 0);
    await until(() => landings.length >= 2);

    expect(sheetClose).toHaveBeenCalledTimes(1);
    expect(viewerClose).not.toHaveBeenCalled();
    expect(landings).toEqual([viewerEntry, null]);
    expect(window.history.state).toEqual(HOME);
  });
});
