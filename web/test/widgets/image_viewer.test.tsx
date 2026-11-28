// @vitest-environment jsdom
import { StrictMode, useState } from 'react';
import {
  act,
  cleanup,
  createEvent,
  fireEvent,
  render,
  screen,
  within,
} from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { MediaTarget } from '../../src/model/media_target';
import { dialogClosed, dialogOpened, holdsFocus } from '../../src/utils/dialog_stack';
import { usePathname } from '../../src/utils/router';
import { ImageViewer } from '../../src/widgets/image_viewer';

/** The state of the page's own entry, to tell it from the overlay's. */
const HOME = { page: 'home' };

/** The viewer is a phone held upright: 400 by 800. */
const WIDTH = 400;

const image = (at: number): string => `https://e.com/${at + 1}.jpg`;
const images = (count: number): string[] => Array.from({ length: count }, (_, at) => image(at));

/** The image loads of the test: nothing loads here unless the test says it did. */
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

/**
 * What the pager is asked to scroll to, each time. It moves the pager as a
 * browser would, which jsdom does not: nothing is laid out here.
 */
const scrollTo = vi.fn(function (this: Element, options?: ScrollToOptions) {
  if (options?.left !== undefined) this.scrollLeft = options.left;
});
/** Every pointer that went down on a page is captured by it. */
const setPointerCapture = vi.fn<(pointerId: number) => void>();

/** The viewer's size, as the browser reports it once it has laid the page out. */
class FakeResizeObserver {
  readonly callback: () => void;

  constructor(callback: () => void) {
    this.callback = callback;
  }

  observe(): void {
    this.callback();
  }

  disconnect(): void {}
}

interface PageProps {
  images: string[];
  initialIndex?: number;
  /** Told each time the viewer asks to be closed. */
  onClosed?: () => void;
  onMore?: (target: MediaTarget) => void;
}

/** A page as the app shows one: the viewer opens from a button, and the page closes it when it asks. */
function Page({ images, initialIndex = 0, onClosed, onMore }: PageProps) {
  const [open, setOpen] = useState(false);
  return (
    <>
      <button onClick={() => setOpen(true)}>그림 보기</button>
      <button>바깥 단추 하나</button>
      <button>바깥 단추 둘</button>
      <ImageViewer
        images={images}
        initialIndex={initialIndex}
        open={open}
        onClose={() => {
          setOpen(false);
          onClosed?.();
        }}
        onMore={onMore}
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

function dialog(): HTMLElement {
  return screen.getByRole('dialog');
}

function pager(): HTMLElement {
  return dialog().querySelector<HTMLElement>('.snap-x')!;
}

/** The Tailwind classes of an element, one by one. */
function classes(el: Element): string[] {
  return (el.getAttribute('class') ?? '').split(/\s+/);
}

function position(): string {
  return screen.getByRole('status').textContent ?? '';
}

function button(name: string): HTMLButtonElement {
  return within(dialog()).getByRole('button', { name });
}

function openViewer(): HTMLElement {
  fireEvent.click(screen.getByRole('button', { name: '그림 보기' }));
  return dialog();
}

/** The browser has brought the pager to rest on page `at`: it says so. */
function scrolledTo(at: number): void {
  const el = pager();
  el.scrollLeft = at * WIDTH;
  fireEvent.scroll(el);
}

/** Where the pager was asked to go, each time: the left edge, and how it was to travel. */
function travels(): Array<[number, string | undefined]> {
  return scrollTo.mock.calls.map(([options]) => [options?.left ?? 0, options?.behavior]);
}

/** The element showing the picture at `url`, once it is shown. */
function picture(url: string): HTMLImageElement {
  const img = document.querySelector<HTMLImageElement>(`img[src="${url}"]:not([aria-hidden])`);
  if (img === null) throw new Error(`No picture is shown for ${url}`);
  return img;
}

/**
 * The picture at `url` arrives. It is `width` by `height`, which the element
 * showing it says as it loads. Returns that element.
 */
async function show(url: string, width: number, height: number): Promise<HTMLImageElement> {
  const load = [...loads].reverse().find((at) => at.src === url);
  if (load === undefined) throw new Error(`Nothing is loading ${url}`);
  await act(() => load.onload?.());
  const measuring = document.querySelector<HTMLImageElement>(`img[src="${url}"]`);
  if (measuring === null) throw new Error(`Nothing is loading ${url}`);
  Object.defineProperty(measuring, 'naturalWidth', { value: width, configurable: true });
  Object.defineProperty(measuring, 'naturalHeight', { value: height, configurable: true });
  await act(() => {
    fireEvent.load(measuring);
  });
  return picture(url);
}

type Step = 'down' | 'move' | 'up' | 'cancel';

const stepEvent = {
  down: createEvent.pointerDown,
  move: createEvent.pointerMove,
  up: createEvent.pointerUp,
  cancel: createEvent.pointerCancel,
};

/** A finger `id` at (`x`, `y`), at `at` ms, on `target`: put down, moved, lifted, or taken by the browser. */
function touch(step: Step, x: number, y: number, at: number, target: Element, id = 1): void {
  const event = stepEvent[step](target, {
    pointerId: id,
    clientX: x,
    clientY: y,
    pointerType: 'touch',
    isPrimary: id === 1,
    button: 0,
    buttons: step === 'down' || step === 'move' ? 1 : 0,
  });
  Object.defineProperty(event, 'timeStamp', { value: at });
  fireEvent(target, event);
}

beforeEach(() => {
  loads.length = 0;
  scrollTo.mockReset();
  setPointerCapture.mockReset();
  vi.stubGlobal('Image', FakeImage);
  vi.stubGlobal('ResizeObserver', FakeResizeObserver);
  vi.spyOn(Element.prototype, 'clientWidth', 'get').mockReturnValue(WIDTH);
  vi.spyOn(Element.prototype, 'clientHeight', 'get').mockReturnValue(800);
  Object.defineProperty(Element.prototype, 'scrollTo', { configurable: true, value: scrollTo });
  Object.defineProperty(Element.prototype, 'setPointerCapture', {
    configurable: true,
    value: setPointerCapture,
  });
  startAtHome();
});

afterEach(async () => {
  vi.useRealTimers();
  // Nothing of this test may traverse the history in the next one.
  cleanup();
  await settle();
  startAtHome();
  delete (Element.prototype as Partial<Element>).scrollTo;
  delete (Element.prototype as Partial<Element>).setPointerCapture;
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

describe('ImageViewer', () => {
  it('shows nothing, and puts nothing on the history, while closed', () => {
    const before = window.history.length;
    render(<Page images={images(3)} />);

    expect(screen.queryByRole('dialog')).toBeNull();
    expect(window.history.length).toBe(before);
    expect(window.history.state).toEqual(HOME);
    expect(document.body.style.overflow).toBe('');
    expect(loads).toHaveLength(0);
  });

  it('does not open with nothing to show, and asks the page to close it', () => {
    const before = window.history.length;
    const onClosed = vi.fn();
    render(<Page images={[]} onClosed={onClosed} />);

    fireEvent.click(screen.getByRole('button', { name: '그림 보기' }));

    expect(screen.queryByRole('dialog')).toBeNull();
    expect(window.history.length).toBe(before);
    expect(window.history.state).toEqual(HOME);
    expect(onClosed).toHaveBeenCalledTimes(1);
    expect(document.body.style.overflow).toBe('');
  });

  it('opened onto nothing at all asks the page to close it too, and puts nothing on the history', () => {
    const before = window.history.length;
    const onClose = vi.fn();

    render(<ImageViewer images={[]} initialIndex={0} open onClose={onClose} />);

    expect(screen.queryByRole('dialog')).toBeNull();
    expect(window.history.length).toBe(before);
    expect(onClose).toHaveBeenCalledTimes(1);
  });

  it('is a modal dialog over everything, named 이미지 보기, with a 44px 닫기', () => {
    render(<Page images={images(3)} />);
    const el = openViewer();
    const close = button('닫기');

    expect(el.getAttribute('aria-modal')).toBe('true');
    expect(el.getAttribute('aria-label')).toBe('이미지 보기');
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

  it('keeps the WebView from showing its own menu on a long-press', async () => {
    render(<Page images={images(1)} />);
    openViewer();
    const img = await show(image(0), 800, 400);

    expect(fireEvent.contextMenu(img)).toBe(false);
    expect(fireEvent.contextMenu(dialog())).toBe(false);
    expect(dialog().className).toContain('select-none');
    expect(dialog().className).toContain('[-webkit-touch-callout:none]');
  });

  it('lets no touch inside reach the page, which listens for them on the window', () => {
    const onTouchMove = vi.fn();
    window.addEventListener('touchmove', onTouchMove);
    render(<Page images={images(1)} />);
    openViewer();

    fireEvent.touchStart(dialog());
    fireEvent.touchMove(dialog());
    fireEvent.touchEnd(dialog());

    expect(onTouchMove).not.toHaveBeenCalled();
    window.removeEventListener('touchmove', onTouchMove);
  });
});

describe('ImageViewer paging', () => {
  it('pages by snapping: one picture per page, as wide as the viewer, travelled smoothly unless motion is reduced', () => {
    render(<Page images={images(12)} initialIndex={2} />);
    openViewer();

    expect(pager().className).toContain('overflow-x-auto');
    expect(pager().className).toContain('snap-x');
    expect(pager().className).toContain('snap-mandatory');
    expect(pager().className).toContain('scroll-smooth');
    expect(pager().className).toContain('motion-reduce:scroll-auto');
    const pages = Array.from(pager().firstElementChild!.children);
    expect(pages).toHaveLength(12);
    for (const page of pages) {
      expect(page.className).toContain('w-full');
      expect(page.className).toContain('snap-center');
      expect(page.className).toContain('snap-always');
    }
    // Put on the page it opened on, without travelling there.
    expect(travels()).toEqual([[800, 'instant']]);
  });

  it('says which image is shown, 3 / 12, and follows the pager as it moves', () => {
    render(<Page images={images(12)} initialIndex={2} />);
    openViewer();

    const shown = screen.getByRole('status');
    expect(shown.getAttribute('aria-label')).toBe('이미지 3 / 12');
    expect(shown.textContent).toBe('3 / 12');

    scrolledTo(3);
    expect(position()).toBe('4 / 12');
    scrolledTo(11);
    expect(position()).toBe('12 / 12');
  });

  it('pages with 이전 and 다음', () => {
    render(<Page images={images(4)} initialIndex={1} />);
    openViewer();
    const prev = button('이전');
    const next = button('다음');
    for (const control of [prev, next]) {
      expect(control.className).toContain('size-11');
      expect(control.querySelector('svg[aria-hidden="true"]')).not.toBeNull();
    }

    fireEvent.click(next);
    expect(travels().at(-1)).toEqual([800, undefined]);
    scrolledTo(2);
    expect(position()).toBe('3 / 4');

    fireEvent.click(prev);
    expect(travels().at(-1)).toEqual([400, undefined]);
  });

  it('turns off 이전 at the first image and 다음 at the last: not focusable, and not looking live', () => {
    render(<Page images={images(3)} />);
    openViewer();

    expect(button('이전').hasAttribute('disabled')).toBe(true);
    expect(button('다음').disabled).toBe(false);
    // The off one is no stop for Tab: back from 닫기 is the last stop, 다음.
    expect(fireEvent.keyDown(document, { key: 'Tab', shiftKey: true })).toBe(false);
    expect(document.activeElement).toBe(button('다음'));

    scrolledTo(2);
    expect(position()).toBe('3 / 3');
    expect(button('다음').className).toContain('disabled:opacity-50');
    expect(button('다음').disabled).toBe(true);
    expect(button('이전').disabled).toBe(false);
  });

  it('has neither a position nor paging buttons with one image', () => {
    render(<Page images={images(1)} />);
    openViewer();

    expect(screen.queryByRole('status')).toBeNull();
    expect(within(dialog()).queryByRole('button', { name: '이전' })).toBeNull();
    expect(within(dialog()).queryByRole('button', { name: '다음' })).toBeNull();
    expect(
      within(dialog())
        .getAllByRole('button')
        .map((control) => control.getAttribute('aria-label'))
    ).toEqual(['닫기', '확대']);
  });

  it('pages with ← and →', () => {
    render(<Page images={images(4)} initialIndex={1} />);
    openViewer();
    scrollTo.mockClear();

    fireEvent.keyDown(document, { key: 'ArrowRight' });
    expect(travels()).toEqual([[800, undefined]]);
    fireEvent.keyDown(document, { key: 'ArrowLeft' });
    expect(travels().at(-1)).toEqual([0, undefined]);

    // At the first image there is nowhere further back.
    scrolledTo(0);
    fireEvent.keyDown(document, { key: 'ArrowLeft' });
    expect(travels()).toHaveLength(2);
  });

  it('puts in only the pages next to the one shown, so a post with dozens of pictures does not load them all', () => {
    render(<Page images={images(40)} initialIndex={20} />);
    openViewer();

    expect(loads.map((load) => load.src)).toEqual([image(19), image(20), image(21)]);
    expect(pager().firstElementChild!.children).toHaveLength(40);

    scrolledTo(21);
    expect(loads.map((load) => load.src)).toEqual([image(19), image(20), image(21), image(22)]);
  });
});

describe('ImageViewer closing', () => {
  it('Esc closes the viewer once, through its history entry', async () => {
    const onClosed = vi.fn();
    render(<Page images={images(2)} onClosed={onClosed} />);
    openViewer();

    fireEvent.keyDown(document, { key: 'Escape' });
    await until(() => onClosed.mock.calls.length > 0);

    expect(onClosed).toHaveBeenCalledTimes(1);
    expect(screen.queryByRole('dialog')).toBeNull();
    expect(window.history.state).toEqual(HOME);
  });

  it('system Back closes the viewer first; only the next Back leaves the page', async () => {
    pageBehind();
    const onClosed = vi.fn();
    const before = window.history.length;
    render(<App images={images(2)} onClosed={onClosed} />);
    openViewer();
    expect(window.history.length).toBe(before + 1);

    act(() => window.history.back());
    await until(() => onClosed.mock.calls.length > 0);

    expect(onClosed).toHaveBeenCalledTimes(1);
    expect(screen.queryByRole('dialog')).toBeNull();
    expect(screen.getByTestId('path').textContent).toBe('/');
    expect(window.history.state).toEqual(HOME);

    act(() => window.history.back());
    await until(() => screen.queryByText('다른 페이지') !== null);
    expect(onClosed).toHaveBeenCalledTimes(1);
  });

  it('닫기 leaves the same entry the same way: one history.back(), and no push', async () => {
    pageBehind();
    const onClosed = vi.fn();
    const back = vi.spyOn(window.history, 'back');
    const push = vi.spyOn(window.history, 'pushState');
    render(<Page images={images(2)} onClosed={onClosed} />);
    openViewer();
    const close = button('닫기');
    expect(push).toHaveBeenCalledTimes(1);

    fireEvent.click(close);
    expect(back).toHaveBeenCalledTimes(1);
    await until(() => onClosed.mock.calls.length > 0);

    expect(onClosed).toHaveBeenCalledTimes(1);
    expect(back).toHaveBeenCalledTimes(1);
    expect(push).toHaveBeenCalledTimes(1);
    expect(window.history.state).toEqual(HOME);
    expect(window.location.pathname).toBe('/');
  });

  it('asked to close twice at once, leaves the one entry and closes once', async () => {
    pageBehind();
    const onClosed = vi.fn();
    render(<Page images={images(2)} onClosed={onClosed} />);
    openViewer();
    const close = button('닫기');

    fireEvent.click(close);
    fireEvent.keyDown(document, { key: 'Escape' });
    await until(() => onClosed.mock.calls.length > 0);
    await settle();

    expect(onClosed).toHaveBeenCalledTimes(1);
    expect(window.history.state).toEqual(HOME);
    expect(window.location.pathname).toBe('/');
  });

  it('stays on its page when an image before it is blocked, and is the last one when that is beyond the end', () => {
    const onMore = vi.fn<(target: MediaTarget) => void>();
    const list = images(5);
    const props = { initialIndex: 2, onMore };
    const { rerender } = render(<Page images={list} {...props} />);
    openViewer();
    fireEvent.click(button('더보기'));
    expect(onMore).toHaveBeenLastCalledWith({ url: list[2], kind: 'image' });

    // The image before the one shown is gone: the page shown is now the one after it.
    rerender(<Page images={[list[0], list[2], list[3], list[4]]} {...props} />);
    expect(position()).toBe('3 / 4');
    fireEvent.click(button('더보기'));
    expect(onMore).toHaveBeenLastCalledWith({ url: list[3], kind: 'image' });

    // Everything after it gone too: it is the last page.
    rerender(<Page images={[list[0], list[2]]} {...props} />);
    expect(position()).toBe('2 / 2');
    expect(button('다음').disabled).toBe(true);
    fireEvent.click(button('더보기'));
    expect(onMore).toHaveBeenLastCalledWith({ url: list[2], kind: 'image' });
  });

  it('closes itself when nothing is left to show, and its history entry goes with it', async () => {
    const onClosed = vi.fn();
    const list = images(3);
    const { rerender } = render(<Page images={list} initialIndex={1} onClosed={onClosed} />);
    openViewer();
    expect(window.history.state).toMatchObject({ overlay: true });
    expect(document.body.style.overflow).toBe('hidden');

    rerender(<Page images={[]} initialIndex={1} onClosed={onClosed} />);

    expect(screen.queryByRole('dialog')).toBeNull();
    expect(onClosed).toHaveBeenCalledTimes(1);
    expect(document.body.style.overflow).toBe('');
    await until(() => window.history.state?.overlay !== true);
    expect(window.history.state).toEqual(HOME);
  });

  it('mounted open under StrictMode, where the effects run twice, puts one entry on the history', async () => {
    const before = window.history.length;

    render(
      <StrictMode>
        <ImageViewer images={images(2)} initialIndex={0} open onClose={() => undefined} />
      </StrictMode>
    );
    await settle();

    expect(window.history.length).toBe(before + 1);
    expect(window.history.state).toMatchObject({ overlay: true });
    expect(document.body.style.overflow).toBe('hidden');
    expect(holdsFocus(dialog())).toBe(true);
  });
});

describe('ImageViewer focus and the page behind', () => {
  it('starts with the focus on 닫기, keeps it in, and gives it back to what opened the viewer', async () => {
    const onClosed = vi.fn();
    render(<Page images={images(3)} onClosed={onClosed} />);
    const opener = screen.getByRole('button', { name: '그림 보기' });
    opener.focus();
    const el = openViewer();
    const close = button('닫기');
    expect(document.activeElement).toBe(close);

    // From the first stop backwards, and from the last stop onwards, Tab stays inside.
    expect(fireEvent.keyDown(document, { key: 'Tab', shiftKey: true })).toBe(false);
    expect(document.activeElement).toBe(button('다음'));
    expect(fireEvent.keyDown(document, { key: 'Tab' })).toBe(false);
    expect(document.activeElement).toBe(close);
    // Between the two it moves as it always does.
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

  it('keeps the page from scrolling while open, and lets it scroll again after', async () => {
    const onClosed = vi.fn();
    render(<Page images={images(2)} onClosed={onClosed} />);
    openViewer();
    expect(document.body.style.overflow).toBe('hidden');

    fireEvent.keyDown(document, { key: 'Escape' });
    await until(() => onClosed.mock.calls.length > 0);

    expect(document.body.style.overflow).toBe('');
  });

  it('leaves the focus to a dialog opened over it, until that one closes', () => {
    render(<Page images={images(3)} />);
    openViewer();
    const close = button('닫기');
    const outside = [
      screen.getByRole('button', { name: '바깥 단추 하나' }),
      screen.getByRole('button', { name: '바깥 단추 둘' }),
    ];

    // A sheet opened from the viewer is in front: it owns the focus, and the keys.
    const sheet = document.createElement('div');
    dialogOpened(sheet);
    outside[0].focus();
    expect(document.activeElement).toBe(outside[0]);
    expect(fireEvent.keyDown(document, { key: 'Tab', shiftKey: true })).toBe(true);
    expect(document.activeElement).toBe(outside[0]);

    // The sheet closed: the viewer is in front again, and takes the focus back.
    dialogClosed(sheet);
    outside[1].focus();
    expect(document.activeElement).toBe(close);
  });
});

describe('ImageViewer pictures', () => {
  it('shows a placeholder the shape of the screen while a picture loads', () => {
    render(<Page images={images(1)} />);
    openViewer();

    const placeholder = dialog().querySelector<HTMLElement>('[data-slot="skeleton"]')!;
    expect(placeholder).not.toBeNull();
    expect(placeholder.className).toContain('bg-muted');
    expect(placeholder.className).toContain('inset-0');
    expect(dialog().querySelector('img')).toBeNull();
    expect(screen.queryByRole('alert')).toBeNull();
    expect(button('확대').disabled).toBe(true);
  });

  it('shows the picture once it has loaded, as the app loads its images: with no Referer', async () => {
    render(<Page images={images(1)} />);
    openViewer();

    expect(loads[0]).toMatchObject({ src: image(0), referrerPolicy: 'no-referrer' });
    const img = await show(image(0), 1200, 800);

    expect(img.getAttribute('referrerpolicy')).toBe('no-referrer');
    expect(img.className).toContain('max-w-full');
    expect(img.className).toContain('max-h-full');
    expect(img.className).toContain('object-contain');
    expect(img.getAttribute('alt')).toBe('1번째 이미지');
    expect(button('확대').disabled).toBe(false);
  });

  it('says when a picture did not load, and asks for it once more', async () => {
    render(<Page images={images(2)} />);
    openViewer();
    const url = image(0);

    await act(() => loads[0].onerror?.());

    const alert = screen.getByRole('alert');
    expect(alert.textContent).toContain('이미지를 불러오지 못했습니다');
    const again = within(alert).getByRole('button', { name: '다시 시도' });
    expect(again.className).toContain('h-11');
    expect(button('확대').disabled).toBe(true);

    fireEvent.click(again);
    expect(loads).toHaveLength(3);
    expect(screen.queryByRole('alert')).toBeNull();
    expect(within(dialog()).queryByRole('button', { name: '다시 시도' })).toBeNull();

    await show(url, 800, 400);
    expect(screen.getByRole('img', { name: '1번째 이미지' })).toBeTruthy();
  });
});

describe('ImageViewer zoom', () => {
  /** Opens a viewer with three pictures and shows the first, 800 by 400: it lies 400 by 200, at (0, 300) to (400, 500). */
  async function opened(): Promise<HTMLImageElement> {
    render(<Page images={images(3)} />);
    openViewer();
    const img = await show(image(0), 800, 400);
    scrollTo.mockClear();
    return img;
  }

  it('zooms to 2x from 확대, about the middle, and back from 원래 크기', async () => {
    const img = await opened();
    const toggle = button('확대');
    expect(toggle.className).toContain('size-11');
    expect(toggle.getAttribute('aria-pressed')).toBe('false');
    expect(img.className).toContain('transition-transform');
    expect(img.className).toContain('duration-250');
    expect(img.className).toContain('ease-out');
    expect(img.className).toContain('motion-reduce:transition-none');

    fireEvent.click(toggle);

    expect(img.style.transform).toBe('translate(-200px, -100px) scale(2)');
    expect(button('원래 크기').getAttribute('aria-pressed')).toBe('true');

    fireEvent.click(button('원래 크기'));

    expect(img.style.transform).toBe('');
    expect(button('확대').getAttribute('aria-pressed')).toBe('false');
    expect(travels()).toHaveLength(0);
  });

  it('zooms with + and −, a step at a time', async () => {
    const img = await opened();

    fireEvent.keyDown(document, { key: '+' });
    expect(img.style.transform).toBe('translate(-200px, -100px) scale(2)');
    fireEvent.keyDown(document, { key: '+' });
    expect(img.style.transform).toBe('translate(-400px, -200px) scale(3)');
    fireEvent.keyDown(document, { key: '-' });
    expect(img.style.transform).toBe('translate(-200px, -100px) scale(2)');
    fireEvent.keyDown(document, { key: '-' });
    expect(img.style.transform).toBe('');
    expect(button('확대').getAttribute('aria-pressed')).toBe('false');
    // Back at 1x, one step down goes nowhere.
    fireEvent.keyDown(document, { key: '-' });
    expect(img.style.transform).toBe('');
  });

  it('shows the next picture at its own size: the zoom was left on the one before', async () => {
    render(<Page images={images(2)} />);
    openViewer();
    await show(image(0), 800, 400);
    const second = await show(image(1), 800, 400);

    fireEvent.click(button('확대'));
    expect(button('원래 크기')).toBeTruthy();
    scrolledTo(1);

    expect(second.style.transform).toBe('');
    expect(button('확대').getAttribute('aria-pressed')).toBe('false');
  });

  it('puts a zoomed picture back on a double-tap', async () => {
    const img = await opened();
    fireEvent.click(button('확대'));

    touch('down', 200, 400, 1000, img);
    touch('up', 200, 400, 1050, img);
    touch('down', 206, 404, 1150, img);
    expect(img.style.transform).toBe('translate(-200px, -100px) scale(2)');
    touch('up', 206, 404, 1180, img);

    expect(img.style.transform).toBe('');
    expect(travels()).toHaveLength(0);
  });

  it('does nothing on a double-tap at 1x, nor on a tap', async () => {
    const img = await opened();

    touch('down', 200, 400, 1000, img);
    touch('up', 200, 400, 1040, img);
    touch('down', 204, 402, 1120, img);
    touch('up', 204, 402, 1160, img);
    touch('down', 300, 450, 2000, img);
    touch('up', 300, 450, 2050, img);

    expect(img.style.transform).toBe('');
    expect(button('확대').getAttribute('aria-pressed')).toBe('false');
    expect(travels()).toHaveLength(0);
  });

  it('zooms by a pinch, up to 4x, about the middle of the fingers, and goes on panning with a finger left', async () => {
    const img = await opened();

    touch('down', 150, 400, 0, img, 1);
    touch('down', 250, 400, 0, img, 2);
    expect(setPointerCapture).toHaveBeenCalledTimes(2);
    touch('move', 100, 400, 16, img, 1);
    touch('move', 300, 400, 16, img, 2);
    // Twice the spread, the middle gone from 150 to 200: the picture follows it.
    expect(img.style.transform).toBe('translate(-200px, -100px) scale(2)');
    expect(classes(img)).toContain('transition-none');
    expect(img.className).toContain('touch-none');

    // As far as it goes, about the middle the fingers began at.
    touch('move', -150, 400, 32, img, 1);
    touch('move', 550, 400, 32, img, 2);
    expect(img.style.transform).toBe('translate(-600px, -300px) scale(4)');
    touch('move', -250, 400, 48, img, 1);
    touch('move', 650, 400, 48, img, 2);
    expect(img.style.transform).toBe('translate(-600px, -300px) scale(4)');
    expect(button('원래 크기').getAttribute('aria-pressed')).toBe('true');

    // One finger lifted: the other drags the picture.
    touch('up', -250, 400, 60, img, 1);
    touch('move', 560, 420, 80, img, 2);
    expect(img.style.transform).toBe('translate(-690px, -280px) scale(4)');

    touch('up', 560, 420, 100, img, 2);
    expect(classes(img)).not.toContain('transition-none');
    // A pinch and a pan never page.
    expect(travels()).toHaveLength(0);
  });

  it('back at 1x by a pinch, is a picture that is not zoomed', async () => {
    const img = await opened();
    fireEvent.click(button('확대'));

    touch('down', 100, 400, 0, img, 1);
    touch('down', 300, 400, 0, img, 2);
    touch('move', 190, 400, 16, img, 1);
    touch('move', 210, 400, 16, img, 2);
    touch('up', 210, 400, 30, img, 2);
    // The finger left has nothing left to drag: it neither zooms nor crashes.
    touch('move', 150, 400, 36, img, 1);
    touch('up', 150, 400, 40, img, 1);

    expect(img.style.transform).toBe('');
    expect(button('확대').getAttribute('aria-pressed')).toBe('false');
    expect(travels()).toHaveLength(0);
  });

  it('leaves a sideways drag on a picture at 1x to the browser, which pages it', async () => {
    const img = await opened();

    touch('down', 300, 400, 0, img);
    touch('move', 200, 400, 16, img);
    touch('move', 100, 400, 32, img);
    expect(img.style.transform).toBe('');
    // Nothing is dragged by hand, and nothing is snapped off.
    expect(travels()).toHaveLength(0);
    expect(pager().style.scrollSnapType).toBe('');

    // The browser takes the gesture, as it does then.
    touch('cancel', 100, 400, 40, img);
    touch('down', 200, 400, 100, img);
    touch('up', 200, 400, 150, img);
    expect(img.style.transform).toBe('');
  });

  it('pages a drag on a picture at 1x that began up or down and turned sideways, which the browser leaves alone', async () => {
    const img = await opened();

    touch('down', 300, 400, 0, img);
    touch('move', 298, 412, 16, img);
    // Down from the start: not the browser's to page.
    expect(travels()).toHaveLength(0);
    expect(img.style.transform).toBe('');

    touch('move', 260, 425, 32, img);
    expect(pager().style.scrollSnapType).toBe('none');
    touch('move', 180, 430, 48, img);
    expect(travels()).toEqual([[80, 'instant']]);
    touch('move', 170, 430, 56, img);
    expect(travels().at(-1)).toEqual([90, 'instant']);

    // Let go at a speed: the next page, smoothly.
    touch('up', 170, 430, 60, img);
    expect(travels().at(-1)).toEqual([400, undefined]);
    expect(pager().style.scrollSnapType).toBe('');
    expect(img.style.transform).toBe('');
  });

  it('does nothing for a drag that stays up or down on a picture at 1x', async () => {
    const img = await opened();

    touch('down', 200, 400, 0, img);
    touch('move', 202, 460, 16, img);
    touch('move', 198, 520, 32, img);
    touch('up', 198, 520, 48, img);

    expect(travels()).toHaveLength(0);
    expect(img.style.transform).toBe('');
    expect(pager().style.scrollSnapType).toBe('');
  });
});

describe('ImageViewer long pictures', () => {
  it('shows a long picture at the width of the viewer, to scroll, with room after it for the chrome, and turns zoom off', async () => {
    render(<Page images={images(2)} />);
    openViewer();
    const img = await show(image(0), 400, 1600);

    const scroller = img.parentElement!;
    expect(scroller.className).toContain('overflow-y-auto');
    expect(scroller.className).toContain('overscroll-contain');
    expect(img.className).toContain('w-full');
    expect(img.className).toContain('touch-pan-y');
    expect(img.className).not.toContain('touch-pan-x');
    expect(scroller.lastElementChild!.className).toContain('h-16');
    expect(button('확대').disabled).toBe(true);
    fireEvent.keyDown(document, { key: '+' });
    expect(img.style.transform).toBe('');
  });

  it('is not long, a picture merely taller than wide: it zooms', async () => {
    render(<Page images={images(1)} />);
    openViewer();
    const img = await show(image(0), 800, 1200);

    expect(img.parentElement!.className).toContain('place-items-center');
    expect(button('확대').disabled).toBe(false);
    fireEvent.click(button('확대'));
    expect(img.style.transform).toBe('translate(-200px, -300px) scale(2)');
  });

  it('drags a long picture from page to page sideways', async () => {
    render(<Page images={images(3)} />);
    openViewer();
    const img = await show(image(0), 400, 1600);
    scrollTo.mockClear();

    touch('down', 300, 400, 0, img);
    touch('move', 260, 402, 16, img);
    // Dragged by hand: not snapped back to its page at every step.
    expect(pager().style.scrollSnapType).toBe('none');
    touch('move', 200, 404, 32, img);
    touch('move', 120, 404, 48, img);
    expect(travels()).toEqual([
      [100, 'instant'],
      [180, 'instant'],
    ]);

    // Let go at a speed: the next page, smoothly.
    touch('up', 120, 404, 56, img);
    expect(travels().at(-1)).toEqual([400, undefined]);
    expect(pager().style.scrollSnapType).toBe('');
  });

  it('lets go of a slow drag on the page it came from', async () => {
    render(<Page images={images(3)} />);
    openViewer();
    const img = await show(image(0), 400, 1600);
    scrollTo.mockClear();

    touch('down', 300, 400, 0, img);
    touch('move', 270, 400, 16, img);
    touch('move', 250, 400, 200, img);
    touch('up', 250, 400, 400, img);

    expect(travels()).toEqual([
      [50, 'instant'],
      [0, undefined],
    ]);
    expect(pager().style.scrollSnapType).toBe('');
  });

  it('leaves a drag up or down on a long picture to the browser, which scrolls it', async () => {
    render(<Page images={images(3)} />);
    openViewer();
    const img = await show(image(0), 400, 1600);
    scrollTo.mockClear();

    touch('down', 200, 400, 0, img);
    touch('move', 201, 460, 16, img);
    touch('cancel', 201, 460, 20, img);
    touch('up', 201, 460, 30, img);

    expect(travels()).toHaveLength(0);
    expect(pager().style.scrollSnapType).toBe('');
  });

  it('snaps the pager back to its page when a second finger turns a drag into a pinch that a long picture does not zoom by', async () => {
    render(<Page images={images(3)} />);
    openViewer();
    const img = await show(image(0), 400, 1600);
    scrollTo.mockClear();

    touch('down', 300, 400, 0, img, 1);
    touch('move', 250, 400, 16, img, 1);
    touch('move', 200, 400, 32, img, 1);
    expect(travels()).toEqual([[100, 'instant']]);

    touch('down', 200, 500, 40, img, 2);
    touch('move', 150, 400, 56, img, 1);
    touch('move', 250, 500, 56, img, 2);

    expect(img.style.transform).toBe('');
    expect(travels().at(-1)).toEqual([0, undefined]);
    expect(pager().style.scrollSnapType).toBe('');
  });
});

describe('ImageViewer and the media action sheet', () => {
  it('asks what to do with the picture shown, from 더보기', async () => {
    const onMore = vi.fn<(target: MediaTarget) => void>();
    render(<Page images={images(2)} initialIndex={1} onMore={onMore} />);
    openViewer();
    const more = button('더보기');
    expect(more.className).toContain('size-11');
    expect(more.getAttribute('aria-haspopup')).toBe('dialog');

    fireEvent.click(more);

    expect(onMore).toHaveBeenCalledTimes(1);
    expect(onMore).toHaveBeenLastCalledWith({ url: image(1), kind: 'image' });
  });

  it('asks the same from a finger held on the picture for half a second', async () => {
    const onMore = vi.fn<(target: MediaTarget) => void>();
    render(<Page images={images(2)} initialIndex={1} onMore={onMore} />);
    openViewer();
    const img = await show(image(1), 800, 400);
    scrollTo.mockClear();
    vi.useFakeTimers();

    touch('down', 200, 400, 0, img);
    vi.advanceTimersByTime(499);
    expect(onMore).not.toHaveBeenCalled();
    vi.advanceTimersByTime(1);
    expect(onMore).toHaveBeenCalledTimes(1);
    expect(onMore).toHaveBeenLastCalledWith({ url: image(1), kind: 'image' });

    // What is left of the gesture is not the viewer's: it neither pages nor zooms.
    touch('move', 100, 400, 700, img);
    touch('up', 100, 400, 800, img);
    expect(travels()).toHaveLength(0);
    expect(img.style.transform).toBe('');
  });

  it('is not a long-press, a finger that moves more than a few pixels; one that only trembles is', async () => {
    const onMore = vi.fn<(target: MediaTarget) => void>();
    render(<Page images={images(2)} initialIndex={1} onMore={onMore} />);
    openViewer();
    const img = await show(image(1), 800, 400);
    vi.useFakeTimers();

    touch('down', 200, 400, 0, img);
    touch('move', 215, 400, 100, img);
    vi.advanceTimersByTime(600);
    touch('up', 215, 400, 700, img);
    expect(onMore).not.toHaveBeenCalled();

    touch('down', 200, 400, 1000, img);
    touch('move', 206, 406, 1100, img);
    vi.advanceTimersByTime(500);
    expect(onMore).toHaveBeenCalledTimes(1);
    touch('up', 206, 406, 1600, img);
  });

  it('is not a long-press once a second finger is down', async () => {
    const onMore = vi.fn<(target: MediaTarget) => void>();
    render(<Page images={images(2)} initialIndex={1} onMore={onMore} />);
    openViewer();
    const img = await show(image(1), 800, 400);
    vi.useFakeTimers();

    touch('down', 200, 400, 0, img, 1);
    touch('down', 260, 400, 100, img, 2);
    vi.advanceTimersByTime(600);

    expect(onMore).not.toHaveBeenCalled();
    touch('up', 260, 400, 700, img, 2);
    touch('up', 200, 400, 710, img, 1);
  });

  it('keeps the finger that made a long-press from going on as a click on whatever is under it when it lifts', async () => {
    render(<Page images={images(1)} onMore={() => undefined} />);
    openViewer();
    const img = await show(image(0), 800, 400);
    vi.useFakeTimers();

    // A tap ends as any touch does.
    touch('down', 200, 400, 0, img);
    touch('up', 200, 400, 50, img);
    expect(fireEvent.touchEnd(dialog())).toBe(true);

    touch('down', 200, 400, 1000, img);
    vi.advanceTimersByTime(500);
    touch('up', 200, 400, 1600, img);
    // The browser clicks where the finger was: by then a sheet the long-press opened is there, and its scrim would close it.
    expect(fireEvent.touchEnd(dialog())).toBe(false);

    // Only the touch of the long-press, not the next tap's.
    touch('down', 200, 400, 3000, img);
    touch('up', 200, 400, 3050, img);
    expect(fireEvent.touchEnd(dialog())).toBe(true);
  });

  it('shows no 더보기 when the page has nothing to do with a picture, and a long-press does nothing either', async () => {
    render(<Page images={images(2)} initialIndex={1} />);
    openViewer();
    const img = await show(image(1), 800, 400);
    vi.useFakeTimers();

    expect(within(dialog()).queryByRole('button', { name: '더보기' })).toBeNull();
    touch('down', 200, 400, 0, img);
    vi.advanceTimersByTime(600);
    touch('up', 200, 400, 700, img);

    expect(
      within(dialog())
        .getAllByRole('button')
        .map((control) => control.getAttribute('aria-label'))
    ).toEqual(['닫기', '확대', '이전', '다음']);
  });
});

/** The root of the app, cut down as in app.tsx: the page is picked by path, and keyed by it. */
function App({ images, onClosed }: PageProps) {
  const pathname = usePathname();
  return (
    <>
      <output data-testid="path">{pathname}</output>
      {pathname === '/' ? (
        <Page key={pathname} images={images} onClosed={onClosed} />
      ) : (
        <p>다른 페이지</p>
      )}
    </>
  );
}
