// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen, within } from '@testing-library/react';
import { StrictMode, useEffect, useRef, useState } from 'react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { dialogClosed, dialogOpened, holdsFocus } from '../../src/utils/dialog_stack';
import { usePathname } from '../../src/utils/router';
import { BottomSheet } from '../../src/widgets/bottom_sheet';

/** The state of the page's own entry, to tell it from the overlay's. */
const HOME = { page: 'home' };

let pageMounts = 0;

interface PageProps {
  /** Whether the page tells the sheet where the focus goes back. */
  focusBack?: boolean;
  /** Told each time the sheet asks to be closed. */
  onClosed?: () => void;
  /** False: the page gives the sheet no title. */
  titled?: boolean;
  height?: 'tall' | 'auto';
}

/** A page as the app shows one: its sheet opens from a button, and it mounts again when the app comes back to it. */
function Page({ focusBack = true, onClosed, titled = true, height }: PageProps) {
  const [open, setOpen] = useState(false);
  const opener = useRef<HTMLButtonElement>(null);
  useEffect(() => {
    pageMounts += 1;
  }, []);

  return (
    <>
      <button ref={opener} onClick={() => setOpen(true)}>
        시트 열기
      </button>
      <BottomSheet
        open={open}
        onClose={() => {
          setOpen(false);
          onClosed?.();
        }}
        returnFocusTo={focusBack ? opener : undefined}
        label="목록"
        title={titled ? '목록' : undefined}
        height={height}
      >
        <a href="https://example.com">링크</a>
        <button type="button">안에 있는 버튼</button>
      </BottomSheet>
    </>
  );
}

/** The root of the app, cut down as in app.tsx: the page is picked by path, and keyed by it. */
function App(props: PageProps) {
  const pathname = usePathname();
  return (
    <>
      <output data-testid="path">{pathname}</output>
      {pathname === '/' ? <Page key={pathname} {...props} /> : <p>다른 페이지</p>}
    </>
  );
}

/** A sheet that is open from the start. */
function OpenSheet() {
  return (
    <BottomSheet open onClose={() => undefined} label="목록">
      <p>안에 있는 글</p>
    </BottomSheet>
  );
}

/** Where the page is shown, as the app's root would tell. */
function Path() {
  return <output data-testid="path">{usePathname()}</output>;
}

/** Two sheets, one opened from inside the other, as a media sheet is opened from a viewer. */
function Stacked() {
  const [outer, setOuter] = useState(false);
  const [inner, setInner] = useState(false);
  return (
    <>
      <Path />
      <button onClick={() => setOuter(true)}>바깥 시트 열기</button>
      <BottomSheet open={outer} onClose={() => setOuter(false)} label="바깥" title="바깥">
        <button onClick={() => setInner(true)}>안쪽 시트 열기</button>
        <button type="button">바깥의 버튼</button>
      </BottomSheet>
      <BottomSheet open={inner} onClose={() => setInner(false)} label="안쪽" height="auto">
        <button type="button">안쪽의 버튼</button>
      </BottomSheet>
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

function sheet(): HTMLElement {
  return screen.getByRole('dialog');
}

function scrim(): HTMLElement {
  return sheet().previousElementSibling as HTMLElement;
}

function open(): HTMLElement {
  fireEvent.click(screen.getByRole('button', { name: '시트 열기' }));
  return screen.getByRole('button', { name: '닫기' });
}

/** A dialog on top of the sheet, as one opened from it: a button the other dialog would trap the focus in. */
function dialogInFront(): HTMLElement {
  const other = document.createElement('div');
  const button = document.createElement('button');
  button.textContent = '앞에 있는 대화상자의 버튼';
  other.append(button);
  document.body.append(other);
  dialogOpened(other);
  return button;
}

describe('BottomSheet', () => {
  beforeEach(() => {
    pageMounts = 0;
    startAtHome();
  });

  afterEach(async () => {
    // Nothing of this test may traverse the history in the next one.
    cleanup();
    await settle();
    startAtHome();
    vi.restoreAllMocks();
  });

  it('shows nothing, locks nothing and puts nothing on the history while closed', () => {
    const before = window.history.length;
    render(<App />);

    expect(screen.queryByRole('dialog')).toBeNull();
    expect(window.history.length).toBe(before);
    expect(document.body.style.overflow).toBe('');
    expect(document.activeElement).not.toBe(screen.getByRole('button', { name: '시트 열기' }));
  });

  it('is a modal dialog named by its label and titled, with a 44px close button at the top right', () => {
    render(<App />);
    const close = open();

    const dialog = sheet();
    expect(dialog.getAttribute('aria-modal')).toBe('true');
    expect(dialog.getAttribute('aria-label')).toBe('목록');
    expect(screen.getByRole('heading', { level: 2, name: '목록' })).toBeTruthy();
    // Most of the screen by default, a card surface with rounded top corners.
    expect(dialog.className).toContain('h-[70dvh]');
    expect(dialog.className).toContain('bg-card');
    expect(dialog.className).toContain('rounded-t-xl');
    expect(dialog.className).toContain('slide-in-from-bottom');
    expect(dialog.className).toContain('duration-250');
    expect(dialog.className).toContain('ease-out');
    expect(dialog.className).toContain('motion-reduce:animate-none');
    // A line under the header, over a scrim that dims the page.
    expect(dialog.querySelectorAll('[data-slot="separator"]')).toHaveLength(1);
    expect(scrim().className).toContain('bg-black/60');
    expect(scrim().getAttribute('aria-hidden')).toBe('true');

    // 44px, and not the 32px of the icon button it is made of.
    expect(close.className).toContain('size-11');
    expect(close.className).not.toContain('size-8');
    expect(close.querySelector('svg[aria-hidden="true"]')).not.toBeNull();
    // Its own content, and nothing else that takes the focus.
    expect(
      within(dialog)
        .getAllByRole('button')
        .map((button) => button.textContent)
    ).toEqual(['', '안에 있는 버튼']);
  });

  it('needs no title: no heading then, and the label still names it', () => {
    render(<App titled={false} />);
    open();

    expect(screen.queryByRole('heading')).toBeNull();
    expect(sheet().getAttribute('aria-label')).toBe('목록');
    expect(screen.getByRole('button', { name: '닫기' })).toBeTruthy();
  });

  it('is as high as its rows, and at most 85dvh, when the page asks for auto', () => {
    render(<App height="auto" />);
    open();

    expect(sheet().className).toContain('max-h-[85dvh]');
    expect(sheet().className).not.toContain('h-[70dvh]');
  });

  it('the close button closes the sheet once, and leaves no entry in the history', async () => {
    pageBehind();
    const onClosed = vi.fn();
    render(<App onClosed={onClosed} />);
    const close = open();

    fireEvent.click(close);
    expect(onClosed).not.toHaveBeenCalled();
    await until(() => onClosed.mock.calls.length > 0);

    expect(onClosed).toHaveBeenCalledTimes(1);
    expect(screen.queryByRole('dialog')).toBeNull();
    expect(screen.getByTestId('path').textContent).toBe('/');
    expect(window.history.state).toEqual(HOME);
    expect(pageMounts).toBe(1);

    // The entry of the sheet is not in the way of the page behind.
    act(() => window.history.back());
    await until(() => screen.queryByText('다른 페이지') !== null);
    expect(onClosed).toHaveBeenCalledTimes(1);
  });

  it('a tap on the scrim closes the sheet once', async () => {
    const onClosed = vi.fn();
    render(<App onClosed={onClosed} />);
    open();

    fireEvent.click(scrim());
    await until(() => onClosed.mock.calls.length > 0);

    expect(onClosed).toHaveBeenCalledTimes(1);
    expect(screen.queryByRole('dialog')).toBeNull();
    expect(window.history.state).toEqual(HOME);
  });

  it('Esc closes the sheet once', async () => {
    const onClosed = vi.fn();
    render(<App onClosed={onClosed} />);
    open();

    fireEvent.keyDown(document, { key: 'Escape' });
    await until(() => onClosed.mock.calls.length > 0);

    expect(onClosed).toHaveBeenCalledTimes(1);
    expect(screen.queryByRole('dialog')).toBeNull();
    expect(window.history.state).toEqual(HOME);
  });

  it('system Back, a popstate that leaves its entry, closes the sheet once before it can leave the page', async () => {
    pageBehind();
    const onClosed = vi.fn();
    const before = window.history.length;
    render(<App onClosed={onClosed} />);
    open();
    expect(window.history.length).toBe(before + 1);
    expect(window.history.state?.overlay).toBe(true);

    act(() => window.history.back());
    await until(() => onClosed.mock.calls.length > 0);

    expect(onClosed).toHaveBeenCalledTimes(1);
    expect(screen.queryByRole('dialog')).toBeNull();
    expect(screen.getByTestId('path').textContent).toBe('/');
    expect(window.history.state).toEqual(HOME);
    expect(pageMounts).toBe(1);

    act(() => window.history.back());
    await until(() => screen.queryByText('다른 페이지') !== null);
    expect(onClosed).toHaveBeenCalledTimes(1);
  });

  it('asked to close twice at once, leaves the one entry and stays on the page', async () => {
    pageBehind();
    const onClosed = vi.fn();
    render(<App onClosed={onClosed} />);
    const close = open();

    fireEvent.click(close);
    fireEvent.click(scrim());
    fireEvent.keyDown(document, { key: 'Escape' });
    await until(() => onClosed.mock.calls.length > 0);
    await settle();

    expect(onClosed).toHaveBeenCalledTimes(1);
    expect(window.history.state).toEqual(HOME);
    expect(window.location.pathname).toBe('/');
    expect(pageMounts).toBe(1);
  });

  it('starts with the focus on the close button and, closed, gives it back to what opened the sheet', async () => {
    const onClosed = vi.fn();
    render(<App onClosed={onClosed} />);
    const opener = screen.getByRole('button', { name: '시트 열기' });
    opener.focus();
    const close = open();

    expect(document.activeElement).toBe(close);

    fireEvent.click(close);
    await until(() => onClosed.mock.calls.length > 0);

    expect(document.activeElement).toBe(opener);
    // Nothing of the sheet is left to hold the focus.
    expect(document.querySelector('[role="dialog"]')).toBeNull();
  });

  it('gives the focus back to what had it when the page names no element', async () => {
    const onClosed = vi.fn();
    render(<App onClosed={onClosed} focusBack={false} />);
    const opener = screen.getByRole('button', { name: '시트 열기' });
    opener.focus();
    const close = open();
    expect(document.activeElement).toBe(close);

    fireEvent.keyDown(document, { key: 'Escape' });
    await until(() => onClosed.mock.calls.length > 0);

    expect(document.activeElement).toBe(opener);
  });

  it('keeps the focus in the sheet: Tab turns back at both ends, and the focus comes back in from outside', () => {
    render(<App />);
    const close = open();
    const opener = screen.getByRole('button', { name: '시트 열기' });
    const link = screen.getByRole('link', { name: '링크' });
    const inner = screen.getByRole('button', { name: '안에 있는 버튼' });

    // From the first stop backwards, and from the last stop onwards, Tab stays inside.
    expect(fireEvent.keyDown(document, { key: 'Tab', shiftKey: true })).toBe(false);
    expect(document.activeElement).toBe(inner);
    expect(fireEvent.keyDown(document, { key: 'Tab' })).toBe(false);
    expect(document.activeElement).toBe(close);
    // Between the two it moves as it always does.
    expect(fireEvent.keyDown(document, { key: 'Tab' })).toBe(true);

    // Sent outside by anything, the focus comes back in.
    opener.focus();
    expect(document.activeElement).toBe(close);
    link.focus();
    expect(document.activeElement).toBe(link);
  });

  it('keeps the page from scrolling while open, and lets it scroll again after', async () => {
    const onClosed = vi.fn();
    render(<App onClosed={onClosed} />);
    const close = open();
    expect(document.body.style.overflow).toBe('hidden');

    fireEvent.click(close);
    await until(() => onClosed.mock.calls.length > 0);

    expect(document.body.style.overflow).toBe('');
  });

  it('gives the page its own scroll setting back, not just an unlocked one', async () => {
    document.body.style.overflow = 'scroll';
    const onClosed = vi.fn();
    render(<App onClosed={onClosed} />);
    const close = open();
    expect(document.body.style.overflow).toBe('hidden');

    fireEvent.click(close);
    await until(() => onClosed.mock.calls.length > 0);
    expect(document.body.style.overflow).toBe('scroll');
    document.body.style.overflow = '';
  });

  it('closed by the page itself, leaves the history, the scroll and the focus as they were', async () => {
    const opener: { current: HTMLButtonElement | null } = { current: null };
    const shown = (openNow: boolean) => (
      <>
        <button ref={opener}>시트 열기</button>
        <BottomSheet open={openNow} onClose={() => undefined} label="목록" returnFocusTo={opener}>
          <p>안에 있는 글</p>
        </BottomSheet>
      </>
    );
    const { rerender } = render(shown(true));
    expect(document.body.style.overflow).toBe('hidden');

    rerender(shown(false));
    await until(() => !window.history.state?.overlay);

    expect(window.history.state).toEqual(HOME);
    expect(document.body.style.overflow).toBe('');
    expect(document.activeElement).toBe(opener.current);
  });

  it('lets no tap or touch inside reach the page', async () => {
    const onClosed = vi.fn();
    let taps = 0;
    function Listening() {
      const [openNow, setOpenNow] = useState(false);
      return (
        <div
          onClick={() => {
            if (openNow) taps += 1;
          }}
        >
          <button onClick={() => setOpenNow(true)}>시트 열기</button>
          <BottomSheet
            open={openNow}
            onClose={() => {
              setOpenNow(false);
              onClosed();
            }}
            label="목록"
          >
            <a href="https://example.com">링크</a>
          </BottomSheet>
        </div>
      );
    }
    // What the pull to refresh of the page listens on.
    const onTouchMove = vi.fn();
    const onTouchStart = vi.fn();
    window.addEventListener('touchmove', onTouchMove);
    window.addEventListener('touchstart', onTouchStart);

    render(<Listening />);
    open();
    fireEvent.click(screen.getByRole('link', { name: '링크' }));
    fireEvent.touchStart(sheet());
    fireEvent.touchMove(sheet());
    fireEvent.touchEnd(sheet());
    fireEvent.touchCancel(sheet());
    expect(taps).toBe(0);
    expect(onTouchStart).not.toHaveBeenCalled();
    expect(onTouchMove).not.toHaveBeenCalled();

    window.removeEventListener('touchmove', onTouchMove);
    window.removeEventListener('touchstart', onTouchStart);
    fireEvent.keyDown(document, { key: 'Escape' });
    await until(() => onClosed.mock.calls.length > 0);
  });

  it('mounted open under StrictMode, where the effect runs twice, puts one entry on the history', async () => {
    const before = window.history.length;

    render(
      <StrictMode>
        <OpenSheet />
      </StrictMode>
    );
    await settle();

    expect(window.history.length).toBe(before + 1);
    expect(window.history.state?.overlay).toBe(true);
    expect(document.body.style.overflow).toBe('hidden');
    expect(document.activeElement).toBe(screen.getByRole('button', { name: '닫기' }));
  });

  /** Two sheets, one opened from inside the other, as a media sheet is opened from a viewer. Both open. */
  function openStacked(): HTMLElement {
    render(<Stacked />);
    fireEvent.click(screen.getByRole('button', { name: '바깥 시트 열기' }));
    // A tap focuses a button before it clicks it; fireEvent only clicks.
    const opener = screen.getByRole('button', { name: '안쪽 시트 열기' });
    opener.focus();
    fireEvent.click(opener);
    return opener;
  }

  function inner(): HTMLElement {
    return screen.getByRole('dialog', { name: '안쪽' });
  }

  it('sits over another sheet, and its close button closes it alone', async () => {
    pageBehind();
    const opener = openStacked();
    expect(
      screen.getAllByRole('dialog').map((dialog) => dialog.getAttribute('aria-label'))
    ).toEqual(['바깥', '안쪽']);
    // The front sheet holds the focus; the one under it does not pull it back.
    expect(document.activeElement).toBe(within(inner()).getByRole('button', { name: '닫기' }));

    fireEvent.click(within(inner()).getByRole('button', { name: '닫기' }));
    await until(() => screen.queryByRole('dialog', { name: '안쪽' }) === null);

    expect(screen.getAllByRole('dialog')).toHaveLength(1);
    expect(document.activeElement).toBe(opener);
    expect(screen.getByTestId('path').textContent).toBe('/');
    // One entry is left, the outer sheet's: Back closes that sheet, not the page.
    act(() => window.history.back());
    await until(() => screen.queryByRole('dialog') === null);
    expect(screen.getByTestId('path').textContent).toBe('/');
    expect(window.history.state).toEqual(HOME);
  });

  it('over another sheet, system Back closes the front one alone, then the one under it', async () => {
    pageBehind();
    const opener = openStacked();
    expect(screen.getAllByRole('dialog')).toHaveLength(2);

    act(() => window.history.back());
    await until(() => screen.queryByRole('dialog', { name: '안쪽' }) === null);

    // The sheet that was under it is still there, with the focus back on what opened the front one.
    expect(screen.getByRole('dialog', { name: '바깥' })).toBeTruthy();
    expect(document.activeElement).toBe(opener);
    expect(screen.getByTestId('path').textContent).toBe('/');
    expect(window.history.state?.overlay).toBe(true);

    act(() => window.history.back());
    await until(() => screen.queryByRole('dialog') === null);
    expect(screen.getByTestId('path').textContent).toBe('/');
    expect(window.history.state).toEqual(HOME);

    // Both entries are gone: the next Back leaves the page.
    act(() => window.history.back());
    await until(() => screen.queryByText('다른 페이지') !== null);
  });

  it('is a dialog of the app while open, the frontmost one, and leaves the stack when it closes', async () => {
    const onClosed = vi.fn();
    render(<App onClosed={onClosed} />);
    open();
    const panel = sheet();
    expect(holdsFocus(panel)).toBe(true);

    fireEvent.keyDown(document, { key: 'Escape' });
    await until(() => onClosed.mock.calls.length > 0);

    expect(holdsFocus(panel)).toBe(false);
  });

  it('holds the focus only while it is the frontmost dialog', async () => {
    const onClosed = vi.fn();
    render(<App onClosed={onClosed} />);
    const close = open();
    const opener = screen.getByRole('button', { name: '시트 열기' });
    // A dialog opened from the sheet, in front of it: the focus is its own now.
    const front = dialogInFront();
    front.focus();
    expect(document.activeElement).toBe(front);

    // Sent outside while that dialog is in front: the sheet under it lets the focus go.
    opener.focus();
    expect(document.activeElement).toBe(opener);

    // That dialog closed. A focus sent outside now is one that left the sheet.
    dialogClosed(front.parentElement as HTMLElement);
    front.focus();
    expect(document.activeElement).toBe(close);
    (front.parentElement as HTMLElement).remove();
  });

  it('turns Tab back only while it is the frontmost dialog', async () => {
    const onClosed = vi.fn();
    render(<App onClosed={onClosed} />);
    const close = open();
    const front = dialogInFront();
    const other = front.parentElement as HTMLElement;

    // In front is another dialog: where Tab goes from here is for that one to say.
    expect(fireEvent.keyDown(document, { key: 'Tab', shiftKey: true })).toBe(true);
    expect(document.activeElement).toBe(close);

    dialogClosed(other);
    other.remove();
    expect(fireEvent.keyDown(document, { key: 'Tab', shiftKey: true })).toBe(false);
    expect(document.activeElement).toBe(screen.getByRole('button', { name: '안에 있는 버튼' }));
  });

  it('answers Esc only while it is the frontmost dialog: Esc is for the one in front', async () => {
    const onClosed = vi.fn();
    render(<App onClosed={onClosed} />);
    open();
    const front = dialogInFront();
    const other = front.parentElement as HTMLElement;

    fireEvent.keyDown(document, { key: 'Escape' });
    await settle();
    expect(onClosed).not.toHaveBeenCalled();
    expect(screen.getByRole('dialog')).toBeTruthy();

    dialogClosed(other);
    other.remove();
    fireEvent.keyDown(document, { key: 'Escape' });
    await until(() => onClosed.mock.calls.length > 0);
    expect(onClosed).toHaveBeenCalledTimes(1);
  });
});
