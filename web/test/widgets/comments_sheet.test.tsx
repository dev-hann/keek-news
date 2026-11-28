// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen, within } from '@testing-library/react';
import { StrictMode, useEffect, useRef, useState } from 'react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { Comment } from '../../src/model/comment';
import { usePathname } from '../../src/utils/router';
import { CommentsSheet } from '../../src/widgets/comments_sheet';

/** The state of the page's own entry, to tell it from the overlay's. */
const HOME = { page: 'home' };

const comment = (id: number, extra: Partial<Comment> = {}): Comment => ({
  id,
  author: '길동이',
  content: '웃긴 글 잘 보고 갑니다',
  date: new Date(2026, 10, 28, 9),
  recommendCount: 3,
  isBest: false,
  mediaBlocks: [],
  replies: [],
  ...extra,
});

/** Four comments: one with a reply that has a reply of its own, and a best one that the data lists second. */
const thread = (): Comment[] => [
  comment(1, {
    content: '첫 댓글',
    replies: [
      comment(11, {
        author: '철수',
        content: 'https://example.com 보세요',
        recommendCount: 0,
        replies: [comment(111, { author: '영희', content: '답글의 답글' })],
      }),
    ],
  }),
  comment(2, { author: '댓글러', content: '베스트 댓글', isBest: true }),
];

let pageMounts = 0;

interface PageProps {
  comments?: Comment[];
  /** Whether the page tells the sheet where the focus goes back. */
  focusBack?: boolean;
  /** Told each time the sheet asks to be closed. */
  onClosed?: () => void;
}

/** A page as the app shows one: its sheet opens from a button, and it mounts again when the app comes back to it. */
function Page({ comments = thread(), focusBack = true, onClosed }: PageProps) {
  const [open, setOpen] = useState(false);
  const opener = useRef<HTMLButtonElement>(null);
  useEffect(() => {
    pageMounts += 1;
  }, []);

  return (
    <>
      <button ref={opener} onClick={() => setOpen(true)}>
        댓글 모두 보기
      </button>
      <CommentsSheet
        comments={comments}
        open={open}
        onClose={() => {
          setOpen(false);
          onClosed?.();
        }}
        returnFocusTo={focusBack ? opener : undefined}
      />
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

/** A page whose sheet is open from the start. */
function OpenPage() {
  return <CommentsSheet comments={thread()} open onClose={() => undefined} />;
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
  fireEvent.click(screen.getByRole('button', { name: '댓글 모두 보기' }));
  return screen.getByRole('button', { name: '닫기' });
}

describe('CommentsSheet', () => {
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

  it('shows nothing, and puts nothing on the history, while closed', () => {
    const before = window.history.length;
    render(<App />);

    expect(screen.queryByRole('dialog')).toBeNull();
    expect(window.history.length).toBe(before);
    expect(document.body.style.overflow).toBe('');
  });

  it('is a modal dialog named after the comments it lists, replies included, with a close button', () => {
    render(<App />);
    const close = open();

    const dialog = sheet();
    expect(dialog.getAttribute('aria-modal')).toBe('true');
    expect(dialog.getAttribute('aria-label')).toBe('댓글 4개');
    expect(screen.getByRole('heading', { level: 2, name: '댓글 4개' })).toBeTruthy();
    expect(dialog.className).toContain('bg-card');
    expect(dialog.className).toContain('h-[70dvh]');

    expect(close.className).toContain('size-11');
    expect(close.querySelector('svg[aria-hidden="true"]')).not.toBeNull();
    // No other control in the sheet: nothing here writes, recommends or logs in.
    expect(within(dialog).getAllByRole('button')).toHaveLength(1);
  });

  it('lists every comment in the order the data gives it, replies under their parent, a best one marked', () => {
    render(<App />);
    open();

    const items = screen.getAllByRole('listitem');
    expect(items.map((item) => item.querySelector('span')?.textContent)).toEqual([
      '길동이',
      '철수',
      '영희',
      '댓글러',
    ]);
    expect(items[0].contains(items[1])).toBe(true);
    expect(items[1].contains(items[2])).toBe(true);
    expect(items[1].classList.contains('pl-4')).toBe(true);
    expect(screen.getAllByText('BEST')).toHaveLength(1);
    // A 0 is a count too.
    expect(screen.getByText('0')).toBeTruthy();
    expect(screen.getByRole('link', { name: 'https://example.com' })).toBeTruthy();
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

  it('system Back closes the sheet first; only the next Back leaves the page', async () => {
    pageBehind();
    const onClosed = vi.fn();
    const before = window.history.length;
    render(<App onClosed={onClosed} />);
    open();
    expect(window.history.length).toBe(before + 1);

    act(() => window.history.back());
    await until(() => onClosed.mock.calls.length > 0);

    expect(onClosed).toHaveBeenCalledTimes(1);
    expect(screen.queryByRole('dialog')).toBeNull();
    expect(screen.getByTestId('path').textContent).toBe('/');
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
    fireEvent.click(close);
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
    const opener = screen.getByRole('button', { name: '댓글 모두 보기' });
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
    const opener = screen.getByRole('button', { name: '댓글 모두 보기' });
    opener.focus();
    open();
    expect(document.activeElement).not.toBe(opener);

    fireEvent.keyDown(document, { key: 'Escape' });
    await until(() => onClosed.mock.calls.length > 0);

    expect(document.activeElement).toBe(opener);
  });

  it('keeps the focus in the sheet: Tab turns back at both ends, and the focus comes back in from outside', () => {
    render(<App />);
    const close = open();
    const opener = screen.getByRole('button', { name: '댓글 모두 보기' });
    const link = screen.getByRole('link', { name: 'https://example.com' });

    // From the first stop backwards, and from the last stop onwards, Tab stays inside.
    expect(fireEvent.keyDown(document, { key: 'Tab', shiftKey: true })).toBe(false);
    expect(document.activeElement).toBe(link);
    expect(fireEvent.keyDown(document, { key: 'Tab' })).toBe(false);
    expect(document.activeElement).toBe(close);
    // Between the two it moves as it always does.
    expect(fireEvent.keyDown(document, { key: 'Tab' })).toBe(true);

    // Sent outside by anything, the focus comes back in.
    opener.focus();
    expect(document.activeElement).toBe(close);
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

  it('says so when there is no comment to list', async () => {
    const onClosed = vi.fn();
    render(<App comments={[]} onClosed={onClosed} />);
    open();

    expect(screen.getByText('댓글이 없습니다.')).toBeTruthy();
    expect(sheet().getAttribute('aria-label')).toBe('댓글 0개');

    fireEvent.keyDown(document, { key: 'Escape' });
    await until(() => onClosed.mock.calls.length > 0);
    expect(window.history.state).toEqual(HOME);
  });

  it('closed by the page itself, leaves the history, the scroll and the focus as they were', async () => {
    const opener: { current: HTMLButtonElement | null } = { current: null };
    const sheetElement = (openNow: boolean) => (
      <>
        <button ref={opener}>댓글 모두 보기</button>
        <CommentsSheet
          comments={thread()}
          open={openNow}
          onClose={() => undefined}
          returnFocusTo={opener}
        />
      </>
    );
    const { rerender } = render(sheetElement(true));
    expect(document.body.style.overflow).toBe('hidden');

    rerender(sheetElement(false));
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
          <button onClick={() => setOpenNow(true)}>댓글 모두 보기</button>
          <CommentsSheet
            comments={thread()}
            open={openNow}
            onClose={() => {
              setOpenNow(false);
              onClosed();
            }}
          />
        </div>
      );
    }
    // What the pull to refresh of the page listens on.
    const onTouchMove = vi.fn();
    window.addEventListener('touchmove', onTouchMove);

    render(<Listening />);
    open();
    fireEvent.click(screen.getByRole('heading', { name: '댓글 4개' }));
    fireEvent.click(screen.getByRole('link', { name: 'https://example.com' }));
    fireEvent.touchMove(sheet());
    expect(taps).toBe(0);
    expect(onTouchMove).not.toHaveBeenCalled();

    window.removeEventListener('touchmove', onTouchMove);
    fireEvent.keyDown(document, { key: 'Escape' });
    await until(() => onClosed.mock.calls.length > 0);
  });

  it('mounted open under StrictMode, where the effect runs twice, puts one entry on the history', async () => {
    const before = window.history.length;

    render(
      <StrictMode>
        <OpenPage />
      </StrictMode>
    );
    await settle();

    expect(window.history.length).toBe(before + 1);
    expect(window.history.state).toMatchObject({ overlay: true });
    expect(document.body.style.overflow).toBe('hidden');
  });
});
