// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen, within } from '@testing-library/react';
import { StrictMode, useState } from 'react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { Comment } from '../../src/model/comment';
import type { VideoBlock } from '../../src/model/content_block';
import type { MediaTarget } from '../../src/model/media_target';
import { videoId, type VideoId } from '../../src/model/video_id';
import { feedVideoPlaybackNotifier } from '../../src/provider/feed_video_playback_provider';
import { dialogClosed, dialogOpened, holdsFocus } from '../../src/utils/dialog_stack';
import { usePathname } from '../../src/utils/router';
import { CommentVideoViewer } from '../../src/widgets/comment_video_viewer';
import { CommentsSheet } from '../../src/widgets/comments_sheet';
import { InlineVideoPlayer } from '../../src/widgets/inline_video_player';

/** The state of the page's own entry, to tell it from the overlay's. */
const HOME = { page: 'home' };

/** The video of the viewer, and the id the page tells it by. */
const ID: VideoId = videoId('humoruniv:7', 0);
/** The id of a video of the card under the viewer. */
const CARD: VideoId = videoId('humoruniv:7', 1);
/** A video no player of these tests has: naming it leaves the one a test left. */
const NOBODY: VideoId = videoId('humoruniv:none', 0);

const clip = (extra: Partial<VideoBlock> = {}): VideoBlock => ({
  type: 'video',
  url: 'https://e.com/v.mp4',
  thumbnailUrl: 'https://e.com/v.jpg',
  ...extra,
});
const CLIP = clip();

/** The image loads of the test: nothing loads unless the test says it did. */
const loads: FakeImage[] = [];

class FakeImage {
  onload: (() => void) | null = null;
  onerror: (() => void) | null = null;
  referrerPolicy = '';
  readonly src: string;

  constructor(src: string) {
    this.src = src;
    loads.push(this);
  }
}

/** What jsdom would never play: which elements `play` and `pause` were called on, and which are playing. */
let plays: HTMLMediaElement[];
let pauses: HTMLMediaElement[];
const playing = new WeakSet<HTMLMediaElement>();

/** The player's way in to an observer the document has none of. */
class FakeIntersectionObserver {
  observe = vi.fn();
  disconnect = vi.fn();
}

beforeEach(() => {
  plays = [];
  pauses = [];
  loads.length = 0;
  feedVideoPlaybackNotifier().setActive(NOBODY);

  vi.spyOn(HTMLMediaElement.prototype, 'play').mockImplementation(function (
    this: HTMLMediaElement
  ) {
    playing.add(this);
    plays.push(this);
    return Promise.resolve();
  });
  vi.spyOn(HTMLMediaElement.prototype, 'pause').mockImplementation(function (
    this: HTMLMediaElement
  ) {
    playing.delete(this);
    pauses.push(this);
  });
  vi.spyOn(HTMLMediaElement.prototype, 'load').mockImplementation(() => undefined);
  vi.spyOn(HTMLMediaElement.prototype, 'paused', 'get').mockImplementation(function (
    this: HTMLMediaElement
  ) {
    return !playing.has(this);
  });

  vi.stubGlobal('IntersectionObserver', FakeIntersectionObserver);
  vi.stubGlobal('Image', FakeImage);
  startAtHome();
});

afterEach(async () => {
  vi.useRealTimers();
  // Nothing of this test may traverse the history in the next one.
  cleanup();
  await settle();
  startAtHome();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

interface PageProps {
  /** Told each time the viewer asks to be closed. */
  onClosed?: () => void;
  onMore?: (target: MediaTarget) => void;
}

/** A page as the app shows one: the viewer opens from a button, and the page closes it when it asks. */
function Page({ onClosed, onMore }: PageProps) {
  const [video, setVideo] = useState<VideoBlock | null>(null);
  return (
    <>
      <button onClick={() => setVideo(CLIP)}>동영상 보기</button>
      <button>바깥 단추 하나</button>
      <button>바깥 단추 둘</button>
      <CommentVideoViewer
        id={ID}
        video={video}
        open
        onClose={() => {
          setVideo(null);
          onClosed?.();
        }}
        onMore={onMore}
      />
    </>
  );
}

/** The root of the app, cut down as in app.tsx: the page is picked by path, and keyed by it. */
function App({ onClosed }: PageProps) {
  const pathname = usePathname();
  return (
    <>
      <output data-testid="path">{pathname}</output>
      {pathname === '/' ? <Page key={pathname} onClosed={onClosed} /> : <p>다른 페이지</p>}
    </>
  );
}

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

/** A page whose comments sheet opens the video of a comment, as the feed does. */
function PageOverSheet({
  onViewerClosed,
  onSheetClosed,
}: {
  onViewerClosed: () => void;
  onSheetClosed: () => void;
}) {
  const [sheetOpen, setSheetOpen] = useState(false);
  const [video, setVideo] = useState<VideoBlock | null>(null);
  return (
    <>
      <button onClick={() => setSheetOpen(true)}>댓글 모두 보기</button>
      <CommentsSheet
        comments={[
          comment(1, { mediaBlocks: [{ type: 'image', url: 'https://e.com/a.jpg' }, CLIP] }),
        ]}
        open={sheetOpen}
        onClose={() => {
          setSheetOpen(false);
          onSheetClosed();
        }}
        onOpenVideo={setVideo}
      />
      <CommentVideoViewer
        id={ID}
        video={video}
        open
        onClose={() => {
          setVideo(null);
          onViewerClosed();
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

/** The viewer's dialog when others are open under it: the one named for what it shows. */
function viewer(): HTMLElement {
  return screen.getByRole('dialog', { name: '동영상 보기' });
}

/** The player's stage: the one thing the viewer shows. */
function stage(): HTMLElement {
  const el = viewer().querySelector<HTMLElement>('.overflow-hidden.size-full');
  if (el === null) throw new Error('The viewer has no stage.');
  return el;
}

/** The video of the player, once it is mounted. */
function video(): HTMLVideoElement {
  const el = stage().querySelector('video');
  if (el === null) throw new Error('The stage has no video.');
  return el;
}

/** The layer that holds every control of the player, and fades as a whole. */
function controls(): HTMLElement {
  const el = stage().querySelector<HTMLElement>('.transition-opacity');
  if (el === null) throw new Error('The stage has no controls.');
  return el;
}

/** The Tailwind classes of an element, one by one. */
function classes(el: Element): string[] {
  return (el.getAttribute('class') ?? '').split(/\s+/);
}

function button(name: string): HTMLButtonElement {
  return within(viewer()).getByRole('button', { name });
}

function openViewer(): HTMLElement {
  fireEvent.click(screen.getByRole('button', { name: '동영상 보기' }));
  return viewer();
}

/** What the browser would have found out about the video. jsdom finds out nothing. */
function knows(
  el: HTMLVideoElement,
  about: { time?: number; duration?: number; loaded?: number }
): void {
  let time = about.time ?? 0;
  const duration = about.duration ?? Number.NaN;
  const loaded = about.loaded ?? 0;
  Object.defineProperty(el, 'currentTime', {
    configurable: true,
    get: () => time,
    set: (to: number) => {
      time = to;
    },
  });
  Object.defineProperty(el, 'duration', { configurable: true, get: () => duration });
  Object.defineProperty(el, 'buffered', {
    configurable: true,
    value: { length: loaded > 0 ? 1 : 0, start: () => 0, end: () => loaded },
  });
}

/** Brings the video to where a browser has it once it plays: a frame drawn, playing, 5 of 31 seconds in. */
function playingAt(el: HTMLVideoElement): void {
  knows(el, { time: 5, duration: 31, loaded: 20 });
  fireEvent.durationChange(el);
  fireEvent.loadedData(el);
  fireEvent.play(el);
  fireEvent.playing(el);
  fireEvent.timeUpdate(el);
}

const finger = { pointerId: 7, isPrimary: true, button: 0, clientX: 100, clientY: 100 };

/** Lets the pointer go where it pressed, and the click that follows that. */
function release(target: Element): void {
  fireEvent.pointerUp(target, { pointerId: 7 });
  fireEvent(target, new PointerEvent('click', { bubbles: true, cancelable: true, pointerId: 7 }));
}

/** A finger moving over, or leaving, `target`; says whether the stage kept the browser from acting on it. */
function touch(kind: 'touchmove' | 'touchend', target: Element): boolean {
  const event = new Event(kind, { bubbles: true, cancelable: true });
  target.dispatchEvent(event);
  return event.defaultPrevented;
}

describe('CommentVideoViewer', () => {
  it('shows nothing, and puts nothing on the history, while closed: no video, or not open', () => {
    const before = window.history.length;
    const { container } = render(
      <>
        <CommentVideoViewer id={ID} video={null} open onClose={() => undefined} />
        <CommentVideoViewer id={ID} video={CLIP} open={false} onClose={() => undefined} />
      </>
    );

    expect(container.querySelector('[role="dialog"]')).toBeNull();
    expect(document.querySelector('[role="dialog"]')).toBeNull();
    expect(window.history.length).toBe(before);
    expect(window.history.state).toEqual(HOME);
    expect(document.body.style.overflow).toBe('');
    // Nothing of the video is asked for, and no other player is told to give way.
    expect(plays).toEqual([]);
    expect(feedVideoPlaybackNotifier().getState()).toBe(NOBODY);
  });

  it('is a modal dialog over everything, named 동영상 보기, on black inside the safe area, with a 44px 닫기', () => {
    render(<Page />);
    const el = openViewer();
    const close = button('닫기');

    expect(el.getAttribute('aria-modal')).toBe('true');
    expect(el.getAttribute('aria-label')).toBe('동영상 보기');
    expect(el.parentElement).toBe(document.body);
    expect(el.className).toContain('fixed');
    expect(el.className).toContain('inset-0');
    expect(el.className).toContain('z-50');
    expect(el.className).toContain('bg-black');
    expect(el.className).toContain('pt-[env(safe-area-inset-top)]');
    expect(el.className).toContain('pb-[env(safe-area-inset-bottom)]');
    expect(close.className).toContain('size-11');
    expect(close.querySelector('svg[aria-hidden="true"]')).not.toBeNull();
  });

  it('plays the video at once, as the one video that may play, and fills the screen: no box of 16:9', async () => {
    render(<Page />);
    openViewer();
    const shown = video();
    const el = stage();

    expect(shown.getAttribute('src')).toBe('https://e.com/v.mp4');
    // Without the 재생 step: nothing was tapped.
    expect(plays).toEqual([shown]);
    expect(feedVideoPlaybackNotifier().getState()).toBe(ID);
    expect(shown.getAttribute('preload')).toBe('auto');
    // The stage holds no shape of its own, whatever the block would know: it is as large as the viewer.
    expect(el.style.aspectRatio).toBe('');
    expect(classes(el)).toEqual(expect.arrayContaining(['size-full']));
    expect(classes(el.parentElement!)).toEqual(expect.arrayContaining(['absolute', 'inset-0']));
    // The video is letterboxed in it.
    expect(classes(shown)).toEqual(expect.arrayContaining(['object-contain', 'size-full']));

    // Loading: the player's own indicator, and then its poster.
    expect(within(el).getByRole('status').textContent).toBe('동영상 불러오는 중');
    await act(() => loads[0].onload?.());
    expect(el.querySelector('img')?.getAttribute('src')).toBe('https://e.com/v.jpg');
  });

  it('a video playing in a card under it gives way: the one the notifier names is the one in the viewer', () => {
    const { container } = render(
      <>
        <InlineVideoPlayer id={CARD} video={clip({ url: 'https://e.com/card.mp4' })} />
        <Page />
      </>
    );
    // The card's video plays, as it does after a tap on the card.
    const cardStage = container.firstElementChild as HTMLElement;
    fireEvent.click(within(cardStage).getByRole('button', { name: '재생' }));
    const cardVideo = cardStage.querySelector('video') as HTMLVideoElement;
    fireEvent.play(cardVideo);
    expect(plays).toEqual([cardVideo]);
    expect(feedVideoPlaybackNotifier().getState()).toBe(CARD);

    openViewer();

    expect(pauses).toEqual([cardVideo]);
    expect(feedVideoPlaybackNotifier().getState()).toBe(ID);
    // The card's video stops loading; the viewer's loads ahead.
    expect(cardVideo.getAttribute('preload')).toBe('none');
    expect(video().getAttribute('preload')).toBe('auto');
  });

  it('says itself when the video cannot be loaded, and 닫기 is still there', () => {
    render(<Page />);
    openViewer();
    const shown = video();

    fireEvent.error(shown);

    const alert = within(stage()).getByRole('alert');
    expect(alert.textContent).toContain('동영상을 불러올 수 없습니다');
    expect(alert.textContent).toContain('탭하여 재시도');
    expect(button('닫기')).toBeTruthy();
    expect(within(stage()).getByRole('button', { name: '탭하여 재시도' })).toBeTruthy();
  });

  it('has no 더보기 where the page has no menu to open', () => {
    render(<Page />);
    openViewer();

    expect(within(viewer()).queryByRole('button', { name: '더보기' })).toBeNull();
  });

  it('has a 44px ⋯ that asks for the video, where the page has a menu to open', () => {
    const onMore = vi.fn<(target: MediaTarget) => void>();
    render(<Page onMore={onMore} />);
    openViewer();

    const more = button('더보기');
    expect(more.className).toContain('size-11');
    expect(more.getAttribute('aria-haspopup')).toBe('dialog');
    expect(more.querySelector('svg[aria-hidden="true"]')).not.toBeNull();

    fireEvent.click(more);

    expect(onMore).toHaveBeenCalledTimes(1);
    expect(onMore).toHaveBeenCalledWith({ url: 'https://e.com/v.mp4', kind: 'video' });
  });

  it('keeps the WebView from showing its own menu on a long-press', () => {
    render(<Page />);
    openViewer();
    const el = stage();

    expect(fireEvent.contextMenu(video())).toBe(false);
    expect(fireEvent.contextMenu(el.parentElement as Element)).toBe(false);
    expect(fireEvent.contextMenu(viewer())).toBe(false);
    expect(viewer().className).toContain('select-none');
    expect(viewer().className).toContain('[-webkit-touch-callout:none]');
  });

  it('lets no touch inside reach the page, which listens for them on the window', () => {
    const onTouchMove = vi.fn();
    window.addEventListener('touchmove', onTouchMove);
    render(<Page />);
    openViewer();

    fireEvent.touchStart(viewer());
    fireEvent.touchMove(stage());
    fireEvent.touchEnd(stage());
    fireEvent.touchCancel(viewer());

    expect(onTouchMove).not.toHaveBeenCalled();
    window.removeEventListener('touchmove', onTouchMove);
  });
});

describe('CommentVideoViewer closing', () => {
  it('닫기 closes the viewer once, through its history entry: one history.back(), and no push', async () => {
    pageBehind();
    const onClosed = vi.fn();
    const back = vi.spyOn(window.history, 'back');
    const push = vi.spyOn(window.history, 'pushState');
    render(<Page onClosed={onClosed} />);
    openViewer();
    expect(push).toHaveBeenCalledTimes(1);

    fireEvent.click(button('닫기'));
    expect(back).toHaveBeenCalledTimes(1);
    expect(onClosed).not.toHaveBeenCalled();
    await until(() => onClosed.mock.calls.length > 0);

    expect(onClosed).toHaveBeenCalledTimes(1);
    expect(back).toHaveBeenCalledTimes(1);
    expect(push).toHaveBeenCalledTimes(1);
    expect(document.querySelector('[role="dialog"]')).toBeNull();
    expect(window.history.state).toEqual(HOME);
    expect(window.location.pathname).toBe('/');
  });

  it('Esc closes the viewer once', async () => {
    const onClosed = vi.fn();
    render(<Page onClosed={onClosed} />);
    openViewer();

    fireEvent.keyDown(document, { key: 'Escape' });
    await until(() => onClosed.mock.calls.length > 0);

    expect(onClosed).toHaveBeenCalledTimes(1);
    expect(document.querySelector('[role="dialog"]')).toBeNull();
    expect(window.history.state).toEqual(HOME);
  });

  it('system Back closes the viewer first; only the next Back leaves the page', async () => {
    pageBehind();
    const onClosed = vi.fn();
    const before = window.history.length;
    render(<App onClosed={onClosed} />);
    openViewer();
    expect(window.history.length).toBe(before + 1);

    act(() => window.history.back());
    await until(() => onClosed.mock.calls.length > 0);

    expect(onClosed).toHaveBeenCalledTimes(1);
    expect(document.querySelector('[role="dialog"]')).toBeNull();
    expect(screen.getByTestId('path').textContent).toBe('/');
    expect(window.history.state).toEqual(HOME);

    act(() => window.history.back());
    await until(() => screen.queryByText('다른 페이지') !== null);
    expect(onClosed).toHaveBeenCalledTimes(1);
  });

  it('asked to close twice at once, leaves the one entry and closes once', async () => {
    const onClosed = vi.fn();
    render(<Page onClosed={onClosed} />);
    openViewer();

    fireEvent.click(button('닫기'));
    fireEvent.keyDown(document, { key: 'Escape' });
    await until(() => onClosed.mock.calls.length > 0);
    await settle();

    expect(onClosed).toHaveBeenCalledTimes(1);
    expect(window.history.state).toEqual(HOME);
    expect(window.location.pathname).toBe('/');
  });

  it('closed by the page itself, takes the video, the history entry, the scroll and the focus off with it', async () => {
    const viewerOf = (shown: VideoBlock | null) => (
      <CommentVideoViewer id={ID} video={shown} open onClose={() => undefined} />
    );
    const { rerender } = render(viewerOf(CLIP));
    expect(document.body.style.overflow).toBe('hidden');
    expect(document.querySelector('video')).not.toBeNull();

    rerender(viewerOf(null));

    expect(document.querySelector('[role="dialog"]')).toBeNull();
    expect(document.querySelector('video')).toBeNull();
    expect(document.body.style.overflow).toBe('');
    await until(() => window.history.state?.overlay !== true);
    expect(window.history.state).toEqual(HOME);
  });

  it('mounted open under StrictMode, where the effects run twice, puts one entry on the history', async () => {
    const before = window.history.length;

    render(
      <StrictMode>
        <CommentVideoViewer id={ID} video={CLIP} open onClose={() => undefined} />
      </StrictMode>
    );
    await settle();

    expect(window.history.length).toBe(before + 1);
    expect(window.history.state).toMatchObject({ overlay: true });
    expect(document.body.style.overflow).toBe('hidden');
    expect(holdsFocus(viewer())).toBe(true);
    // One player, playing once.
    expect(plays).toHaveLength(1);
  });
});

describe('CommentVideoViewer focus and the page behind', () => {
  it('starts with the focus on 닫기, keeps it in, and gives it back to what opened the viewer', async () => {
    const onClosed = vi.fn();
    render(<Page onClosed={onClosed} />);
    const opener = screen.getByRole('button', { name: '동영상 보기' });
    opener.focus();
    const el = openViewer();
    const close = button('닫기');

    expect(document.activeElement).toBe(close);

    // From the last stop onwards, Tab stays inside; at the first stop backwards too.
    const last = within(stage()).getByRole('button', { name: '음소거 해제' });
    last.focus();
    expect(fireEvent.keyDown(document, { key: 'Tab' })).toBe(false);
    expect(document.activeElement).toBe(close);
    expect(fireEvent.keyDown(document, { key: 'Tab', shiftKey: true })).toBe(false);
    expect(document.activeElement).toBe(last);
    // Between the two it moves as it always does.
    close.focus();
    expect(fireEvent.keyDown(document, { key: 'Tab' })).toBe(true);

    // Sent outside by anything, the focus comes back in.
    screen.getByRole('button', { name: '바깥 단추 하나' }).focus();
    expect(document.activeElement).toBe(close);

    fireEvent.click(close);
    await until(() => onClosed.mock.calls.length > 0);

    expect(document.activeElement).toBe(opener);
    expect(holdsFocus(el)).toBe(false);
    expect(document.querySelector('[role="dialog"]')).toBeNull();
  });

  it('reaches 닫기 and ⋯ by Tab before the controls of the player, as they are above them on the screen', () => {
    render(<Page onMore={vi.fn()} />);
    openViewer();
    playingAt(video());

    const stops = Array.from(viewer().querySelectorAll('button:not([disabled])')).map((control) =>
      control.getAttribute('aria-label')
    );

    expect(stops.slice(0, 3)).toEqual(['닫기', '더보기', '일시정지']);
    expect(stops).toContain('음소거 해제');
  });

  it('keeps the page from scrolling while open, and lets it scroll again after', async () => {
    const onClosed = vi.fn();
    render(<Page onClosed={onClosed} />);
    openViewer();
    expect(document.body.style.overflow).toBe('hidden');

    fireEvent.keyDown(document, { key: 'Escape' });
    await until(() => onClosed.mock.calls.length > 0);

    expect(document.body.style.overflow).toBe('');
  });

  it('leaves the focus to a dialog opened over it, until that one closes', () => {
    render(<Page />);
    openViewer();
    const close = button('닫기');
    const [first, second] = [
      screen.getByRole('button', { name: '바깥 단추 하나' }),
      screen.getByRole('button', { name: '바깥 단추 둘' }),
    ];

    // A sheet opened from the viewer is in front: it owns the focus, and the keys.
    const sheet = document.createElement('div');
    dialogOpened(sheet);
    first.focus();
    expect(document.activeElement).toBe(first);
    expect(fireEvent.keyDown(document, { key: 'Tab', shiftKey: true })).toBe(true);
    expect(document.activeElement).toBe(first);

    // The sheet closed: the viewer is in front again, and takes the focus back.
    dialogClosed(sheet);
    second.focus();
    expect(document.activeElement).toBe(close);
  });
});

describe('CommentVideoViewer and the long press', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  it('asks for the sheet after half a second on the stage, once, and not before', () => {
    const onMore = vi.fn<(target: MediaTarget) => void>();
    render(<Page onMore={onMore} />);
    openViewer();

    // The finger lands on the video itself.
    fireEvent.pointerDown(video(), finger);
    act(() => vi.advanceTimersByTime(499));
    expect(onMore).not.toHaveBeenCalled();

    act(() => vi.advanceTimersByTime(1));
    expect(onMore).toHaveBeenCalledTimes(1);
    expect(onMore).toHaveBeenCalledWith({ url: 'https://e.com/v.mp4', kind: 'video' });

    // However long the finger stays.
    act(() => vi.advanceTimersByTime(5000));
    expect(onMore).toHaveBeenCalledTimes(1);
  });

  it('is no long press when the finger is let go first, moves more than about 10px, or the browser takes the gesture', () => {
    const onMore = vi.fn<(target: MediaTarget) => void>();
    render(<Page onMore={onMore} />);
    openViewer();
    const el = stage();

    // Let go first: that is a tap on the player.
    fireEvent.pointerDown(el, finger);
    act(() => vi.advanceTimersByTime(300));
    fireEvent.pointerUp(el, { pointerId: 7 });
    act(() => vi.advanceTimersByTime(1000));

    // Moved: that is a drag.
    fireEvent.pointerDown(el, finger);
    act(() => vi.advanceTimersByTime(200));
    fireEvent.pointerMove(el, { pointerId: 7, clientX: 115, clientY: 100 });
    act(() => vi.advanceTimersByTime(1000));
    fireEvent.pointerUp(el, { pointerId: 7 });

    // Taken by the browser.
    fireEvent.pointerDown(el, finger);
    act(() => vi.advanceTimersByTime(200));
    fireEvent.pointerCancel(el, { pointerId: 7 });
    act(() => vi.advanceTimersByTime(1000));

    expect(onMore).not.toHaveBeenCalled();
  });

  it('still counts when the finger trembles a little', () => {
    const onMore = vi.fn<(target: MediaTarget) => void>();
    render(<Page onMore={onMore} />);
    openViewer();
    const el = stage();

    fireEvent.pointerDown(el, finger);
    act(() => vi.advanceTimersByTime(200));
    fireEvent.pointerMove(el, { pointerId: 7, clientX: 106, clientY: 105 });
    act(() => vi.advanceTimersByTime(300));

    expect(onMore).toHaveBeenCalledTimes(1);
  });

  it('is for the first finger and the main button only', () => {
    const onMore = vi.fn<(target: MediaTarget) => void>();
    render(<Page onMore={onMore} />);
    openViewer();
    const el = stage();

    fireEvent.pointerDown(el, { ...finger, isPrimary: false });
    fireEvent.pointerDown(el, { ...finger, button: 2 });
    act(() => vi.advanceTimersByTime(1000));

    expect(onMore).not.toHaveBeenCalled();
  });

  it('does not start on the scrubber: a thumb held still before a drag is not a press on the video', () => {
    const onMore = vi.fn<(target: MediaTarget) => void>();
    render(<Page onMore={onMore} />);
    openViewer();
    playingAt(video());

    fireEvent.pointerDown(within(stage()).getByRole('slider', { name: '재생 위치' }), finger);
    act(() => vi.advanceTimersByTime(1000));

    expect(onMore).not.toHaveBeenCalled();
  });

  it('letting go of a long press is not also a tap on the player, and that finger moves nothing and clicks nothing', () => {
    const onMore = vi.fn<(target: MediaTarget) => void>();
    render(<Page onMore={onMore} />);
    openViewer();
    playingAt(video());
    const el = stage();

    // Free to be an ordinary touch.
    expect(touch('touchmove', el)).toBe(false);
    fireEvent.pointerDown(el, finger);
    expect(touch('touchmove', el)).toBe(false);

    act(() => vi.advanceTimersByTime(500));
    expect(onMore).toHaveBeenCalledTimes(1);

    // While that finger is down, its move starts no scroll, and its letting go is no click at all.
    expect(touch('touchmove', el)).toBe(true);
    expect(touch('touchend', el)).toBe(true);
    // A click that comes all the same, as a mouse's does: a tap on the stage would hide the controls. This one does not.
    release(el);
    expect(classes(controls())).toContain('opacity-100');
    expect(onMore).toHaveBeenCalledTimes(1);

    // The next tap is a tap.
    fireEvent.pointerDown(el, finger);
    expect(touch('touchend', el)).toBe(false);
    release(el);
    expect(classes(controls())).toContain('opacity-0');
  });

  it('a click of the keyboard is never taken for how a long press ended', () => {
    const onMore = vi.fn<(target: MediaTarget) => void>();
    render(<Page onMore={onMore} />);
    openViewer();
    playingAt(video());
    const el = stage();

    // A mouse that pressed long and was let go elsewhere: its click never came here.
    fireEvent.pointerDown(el, { ...finger, pointerId: 1 });
    act(() => vi.advanceTimersByTime(500));
    fireEvent.pointerUp(el, { pointerId: 1 });
    expect(onMore).toHaveBeenCalledTimes(1);

    // Enter on a control of the player: a click from no pointer at all, as Chromium sends it.
    fireEvent(el, new PointerEvent('click', { bubbles: true, cancelable: true, pointerId: -1 }));
    expect(classes(controls())).toContain('opacity-0');
    fireEvent(el, new MouseEvent('click', { bubbles: true, cancelable: true }));
    expect(classes(controls())).toContain('opacity-100');
  });

  it('does nothing where the page has no menu to open', () => {
    render(<Page />);
    openViewer();
    const el = stage();

    fireEvent.pointerDown(el, finger);
    act(() => vi.advanceTimersByTime(1000));

    expect(within(viewer()).queryByRole('button', { name: '더보기' })).toBeNull();
    expect(touch('touchmove', el)).toBe(false);
  });

  it('forgets a press it was still watching when the viewer closes', async () => {
    const onMore = vi.fn<(target: MediaTarget) => void>();
    const viewerOf = (shown: VideoBlock | null) => (
      <CommentVideoViewer id={ID} video={shown} open onClose={() => undefined} onMore={onMore} />
    );
    const { rerender } = render(viewerOf(CLIP));

    fireEvent.pointerDown(stage(), finger);
    rerender(viewerOf(null));
    act(() => vi.advanceTimersByTime(1000));

    expect(onMore).not.toHaveBeenCalled();
    // The closing of the viewer steps the history: jsdom does that a tick later, and only under real timers.
    vi.useRealTimers();
    await settle();
  });
});

describe('CommentVideoViewer over the comments sheet', () => {
  it('Back closes the viewer alone: the sheet under it stays, with the page still locked, until the next Back', async () => {
    const onViewerClosed = vi.fn();
    const onSheetClosed = vi.fn();
    const before = window.history.length;
    render(<PageOverSheet onViewerClosed={onViewerClosed} onSheetClosed={onSheetClosed} />);

    fireEvent.click(screen.getByRole('button', { name: '댓글 모두 보기' }));
    expect(window.history.length).toBe(before + 1);
    // The tap that opens the video focuses its thumbnail, as a browser does.
    const thumbnail = screen.getByRole('button', { name: '길동이의 댓글 동영상' });
    thumbnail.focus();
    fireEvent.click(thumbnail);

    // The viewer is over the sheet: two dialogs, two entries, the viewer's on top.
    expect(screen.getAllByRole('dialog')).toHaveLength(2);
    expect(window.history.length).toBe(before + 2);
    expect(holdsFocus(viewer())).toBe(true);
    expect(document.body.style.overflow).toBe('hidden');

    act(() => window.history.back());
    await until(() => onViewerClosed.mock.calls.length > 0);

    expect(onViewerClosed).toHaveBeenCalledTimes(1);
    expect(onSheetClosed).not.toHaveBeenCalled();
    expect(screen.queryByRole('dialog', { name: '동영상 보기' })).toBeNull();
    expect(screen.getByRole('dialog', { name: '댓글 1개' })).toBeTruthy();
    // The sheet's entry is the one shown now, and the sheet still keeps the page from scrolling.
    expect(window.history.state).toMatchObject({ overlay: true });
    expect(window.location.pathname).toBe('/');
    expect(document.body.style.overflow).toBe('hidden');
    // The focus went back to what opened the viewer: the thumbnail in the sheet.
    expect(document.activeElement).toBe(thumbnail);

    act(() => window.history.back());
    await until(() => onSheetClosed.mock.calls.length > 0);

    expect(onSheetClosed).toHaveBeenCalledTimes(1);
    expect(onViewerClosed).toHaveBeenCalledTimes(1);
    expect(screen.queryByRole('dialog')).toBeNull();
    expect(window.history.state).toEqual(HOME);
    expect(document.body.style.overflow).toBe('');
  });
});
