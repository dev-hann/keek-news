// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen, within } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { VideoBlock } from '../../src/model/content_block';
import type { FeedItemKey } from '../../src/model/feed_item';
import type { VideoId } from '../../src/model/video_id';

let FeedImageCarousel: typeof import('../../src/widgets/feed_image_carousel').FeedImageCarousel;

/** The player as the pager sees it: it writes what it was given into the page. */
function FakePlayer({ id, video }: { id: VideoId; video: VideoBlock }) {
  return <div data-testid="player" data-id={id} data-url={video.url} />;
}

/** What the pager asks of the layout: it reports the height of each page when told to. */
class FakeResizeObserver {
  static latest: FakeResizeObserver | null = null;
  readonly callback: ResizeObserverCallback;
  readonly observed: Element[] = [];

  constructor(callback: ResizeObserverCallback) {
    this.callback = callback;
    FakeResizeObserver.latest = this;
  }

  observe(target: Element): void {
    this.observed.push(target);
  }

  disconnect(): void {
    this.observed.length = 0;
  }
}

const postKey: FeedItemKey = 'humoruniv:123';
const A = 'https://e.com/a.jpg';
const B = 'https://e.com/b.jpg';
const C = 'https://e.com/c.jpg';
const D = 'https://e.com/d.jpg';
/** A video from outside the community: the web app has no player for it. */
const EMBED = 'https://youtu.be/abc';

const video = (url: string, extra: Partial<VideoBlock> = {}): VideoBlock => ({
  type: 'video',
  url,
  ...extra,
});

/** What the pager hands the page through `onMore`: the media of the page shown. */
type Target = { url: string; kind: string };

function area(container: HTMLElement): HTMLElement {
  return container.firstElementChild as HTMLElement;
}

function scrollerOf(container: HTMLElement): HTMLElement {
  return area(container).firstElementChild as HTMLElement;
}

function pagesOf(container: HTMLElement): HTMLElement[] {
  return Array.from(scrollerOf(container).children) as HTMLElement[];
}

/** The page of the pager that holds `element`. */
function pageHolding(container: HTMLElement, element: Element): HTMLElement {
  return pagesOf(container).find((page) => page.contains(element)) as HTMLElement;
}

/** Puts the pager at the page `index`, as a swipe that settled there: `width` wide, scrolled to it. */
function swipeTo(scroller: HTMLElement, index: number, width = 400): void {
  vi.spyOn(scroller, 'clientWidth', 'get').mockReturnValue(width);
  vi.spyOn(scroller, 'scrollLeft', 'get').mockReturnValue(index * width);
  fireEvent.scroll(scroller);
}

/** The picture at `img` has loaded: `width` by `height`. jsdom never loads one by itself. */
function loads(img: HTMLImageElement, width: number, height: number): void {
  Object.defineProperty(img, 'naturalWidth', { value: width, configurable: true });
  Object.defineProperty(img, 'naturalHeight', { value: height, configurable: true });
  fireEvent.load(img);
}

/** Tells the pager how tall its pages are, from the first, as the ResizeObserver would. */
function pagesAre(...heights: number[]): void {
  const observer = FakeResizeObserver.latest;
  if (observer === null) throw new Error('the pager is observing no page');
  const entries = observer.observed.map((target, index) => ({
    target,
    borderBoxSize: [{ blockSize: heights[index] ?? 0 }],
  }));
  act(() => {
    observer.callback(
      entries as unknown as ResizeObserverEntry[],
      observer as unknown as ResizeObserver
    );
  });
}

function position(): HTMLElement {
  return screen.getByRole('status');
}

function more(): HTMLElement {
  return screen.getByRole('button', { name: '더보기' });
}

const finger = { pointerId: 7, isPrimary: true, button: 0, clientX: 100, clientY: 100 };

/** Lets the pointer go where it pressed, and the click that follows that. */
function release(target: Element, pointerId = 7): void {
  fireEvent.pointerUp(target, { pointerId });
  fireEvent(target, new PointerEvent('click', { bubbles: true, cancelable: true, pointerId }));
}

/** A finger moving over `target`; says whether the media kept the browser from acting on it. */
function touchMove(target: Element): boolean {
  const event = new Event('touchmove', { bubbles: true, cancelable: true });
  target.dispatchEvent(event);
  return event.defaultPrevented;
}

describe('FeedImageCarousel', () => {
  const scrollTo = vi.fn();

  beforeEach(async () => {
    vi.resetModules();
    FakeResizeObserver.latest = null;
    // React reports markup that cannot be, a button inside one, on the console only. It is collected to fail the test.
    vi.spyOn(console, 'error').mockImplementation(() => undefined);
    vi.doMock('../../src/widgets/inline_video_player', () => ({ InlineVideoPlayer: FakePlayer }));
    ({ FeedImageCarousel } = await import('../../src/widgets/feed_image_carousel'));
    vi.stubGlobal('ResizeObserver', FakeResizeObserver);
    // jsdom has no element scrolling: the pager's one programmatic scroll is collected here.
    scrollTo.mockClear();
    Object.defineProperty(Element.prototype, 'scrollTo', { value: scrollTo, configurable: true });
  });

  afterEach(() => {
    cleanup();
    const impossible = vi
      .mocked(console.error)
      .mock.calls.filter(
        (args) =>
          typeof args[0] === 'string' &&
          /cannot (be a descendant of|contain a nested)/.test(args[0])
      );
    expect(impossible.map((args) => args.slice(0, 3).join(' '))).toEqual([]);
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
    vi.useRealTimers();
    delete (Element.prototype as { scrollTo?: unknown }).scrollTo;
  });

  it('shows nothing without media', () => {
    const { container } = render(<FeedImageCarousel postKey={postKey} images={[]} videos={[]} />);

    expect(container.firstChild).toBeNull();
  });

  it('shows nothing for an embed from outside that has no poster', () => {
    const { container } = render(
      <FeedImageCarousel postKey={postKey} images={[]} videos={[video(EMBED)]} />
    );

    expect(container.firstChild).toBeNull();
  });

  it('shows the images first, then the videos, one page each', () => {
    const { container } = render(
      <FeedImageCarousel
        postKey={postKey}
        images={[A, B]}
        videos={[video('https://e.com/v.mp4'), video('https://e.com/w.mp4')]}
      />
    );

    const pages = pagesOf(container);
    const shown = (page: HTMLElement): string | null | undefined =>
      page.querySelector('img')?.src ??
      page.querySelector('[data-testid="player"]')?.getAttribute('data-url');
    expect(pages.map(shown)).toEqual([A, B, 'https://e.com/v.mp4', 'https://e.com/w.mp4']);

    // Every page is as wide as the card, and is where a swipe stops: the scroller snaps to each.
    for (const page of pages) {
      expect(page.className).toContain('w-full');
      expect(page.className).toContain('shrink-0');
      expect(page.className).toContain('snap-start');
    }
    const classes = scrollerOf(container).className;
    expect(classes).toContain('snap-x');
    expect(classes).toContain('snap-mandatory');
    expect(classes).toContain('overflow-x-auto');
  });

  it('says where it is only when there is more than one page', () => {
    const alone = render(<FeedImageCarousel postKey={postKey} images={[A]} videos={[]} />);
    expect(screen.queryByRole('status')).toBeNull();
    alone.unmount();

    render(<FeedImageCarousel postKey={postKey} images={[A, B, C]} videos={[]} />);
    expect(position().getAttribute('aria-label')).toBe('이미지 1 / 3');
    expect(position().textContent).toBe('1 / 3');
  });

  it('counts images and videos both, and follows a swipe', () => {
    const { container } = render(
      <FeedImageCarousel
        postKey={postKey}
        images={Array.from({ length: 9 }, (_, index) => `https://e.com/${index}.jpg`)}
        videos={[video('https://e.com/v.mp4')]}
      />
    );
    const scroller = scrollerOf(container);
    const where = (): string | null => position().getAttribute('aria-label');

    expect(where()).toBe('이미지 1 / 10');

    swipeTo(scroller, 2);
    expect(where()).toBe('이미지 3 / 10');
    expect(position().textContent).toBe('3 / 10');

    // Between two pages it is the nearer one; past the end it is the last one.
    swipeTo(scroller, 5.4);
    expect(where()).toBe('이미지 6 / 10');
    swipeTo(scroller, 99);
    expect(where()).toBe('이미지 10 / 10');
    swipeTo(scroller, 0);
    expect(where()).toBe('이미지 1 / 10');
  });

  it('is writing on a dark pill at a corner of the media area, out of the way of a tap', () => {
    const { container } = render(
      <FeedImageCarousel postKey={postKey} images={[A, B]} videos={[]} />
    );

    const pill = position();
    expect(pill.tagName).toBe('SPAN');
    const classes = pill.className;
    expect(classes).toContain('bg-black/60');
    expect(classes).toContain('text-white');
    expect(classes).toContain('rounded-full');
    // 8px in from the corner.
    expect(classes).toContain('top-2');
    expect(classes).toContain('left-2');
    expect(classes).toContain('pointer-events-none');
    expect(area(container).className).toContain('relative');
  });

  it('⋯ asks for the sheet for the page shown: an image, then a video, then an embed', () => {
    const onMore = vi.fn<(target: Target) => void>();
    const { container } = render(
      <FeedImageCarousel
        postKey={postKey}
        images={[A]}
        videos={[
          video('https://e.com/v.mp4'),
          video(EMBED, { thumbnailUrl: 'https://img.test/1.jpg' }),
        ]}
        onMore={onMore}
      />
    );
    const scroller = scrollerOf(container);

    fireEvent.click(more());
    expect(onMore).toHaveBeenLastCalledWith({ url: A, kind: 'image' });

    swipeTo(scroller, 1);
    fireEvent.click(more());
    expect(onMore).toHaveBeenLastCalledWith({ url: 'https://e.com/v.mp4', kind: 'video' });

    swipeTo(scroller, 2);
    fireEvent.click(more());
    expect(onMore).toHaveBeenLastCalledWith({ url: EMBED, kind: 'external' });
    expect(onMore).toHaveBeenCalledTimes(3);
  });

  it('⋯ is a 44px button that says it opens a dialog, and is not there without onMore', () => {
    const withMore = render(
      <FeedImageCarousel postKey={postKey} images={[A]} videos={[]} onMore={vi.fn()} />
    );
    const button = more();
    expect(button.getAttribute('aria-haspopup')).toBe('dialog');
    // 44px, and not the 32px of the icon button it is made of.
    expect(button.className).toContain('size-11');
    expect(button.className).not.toContain('size-8');
    expect(button.querySelector('svg[aria-hidden="true"]')).not.toBeNull();
    withMore.unmount();

    render(<FeedImageCarousel postKey={postKey} images={[A]} videos={[]} />);
    expect(screen.queryByRole('button', { name: '더보기' })).toBeNull();
  });

  it('a tap on an image opens the viewer on that image', () => {
    const onOpenImage = vi.fn<(index: number) => void>();
    render(
      <FeedImageCarousel postKey={postKey} images={[A, B]} videos={[]} onOpenImage={onOpenImage} />
    );

    fireEvent.click(screen.getByRole('button', { name: '2번째 이미지' }));
    expect(onOpenImage).toHaveBeenCalledTimes(1);
    expect(onOpenImage).toHaveBeenCalledWith(1);

    fireEvent.click(screen.getByRole('button', { name: '1번째 이미지' }));
    expect(onOpenImage).toHaveBeenLastCalledWith(0);
  });

  it('where nothing can open a viewer, the picture is not a button', () => {
    render(<FeedImageCarousel postKey={postKey} images={[A]} videos={[]} />);

    expect(screen.getByRole('img', { name: '1번째 이미지' })).toBeTruthy();
    expect(screen.queryByRole('button')).toBeNull();
  });

  it('a video page carries the player, named for the post and for which video of it it is', () => {
    const { container } = render(
      <FeedImageCarousel
        postKey={postKey}
        images={[A]}
        videos={[
          video('https://e.com/v.mp4'),
          video('https://e.com/w.mp4', { thumbnailUrl: 'https://img.test/w.jpg' }),
        ]}
      />
    );

    const players = Array.from(container.querySelectorAll('[data-testid="player"]'));
    expect(players.map((player) => player.getAttribute('data-id'))).toEqual([
      'humoruniv:123#0',
      'humoruniv:123#1',
    ]);
    expect(players.map((player) => player.getAttribute('data-url'))).toEqual([
      'https://e.com/v.mp4',
      'https://e.com/w.mp4',
    ]);
    // The player is the page: nothing of the pager is put around it.
    expect(players.map((player) => player.parentElement)).toEqual(pagesOf(container).slice(1));
  });

  it('a video with no poster still gets its page', () => {
    render(
      <FeedImageCarousel postKey={postKey} images={[]} videos={[video('https://e.com/v.mp4')]} />
    );

    expect(screen.getByTestId('player').getAttribute('data-id')).toBe('humoruniv:123#0');
  });

  it('an embed from outside is shown by its poster, as a picture with no player and no button', () => {
    const { container } = render(
      <FeedImageCarousel
        postKey={postKey}
        images={[A]}
        videos={[video(EMBED, { thumbnailUrl: 'https://img.test/1.jpg' })]}
      />
    );

    expect(screen.queryByTestId('player')).toBeNull();
    const poster = screen.getByRole('img', { name: '동영상 미리보기' });
    expect(poster).toHaveProperty('src', 'https://img.test/1.jpg');
    expect(pageHolding(container, poster).querySelector('button')).toBeNull();
    // It is a page, and it counts as one.
    expect(pagesOf(container)).toHaveLength(2);
    expect(position().getAttribute('aria-label')).toBe('이미지 1 / 2');
  });

  it('holds a square for a picture until its size is known, then takes its ratio, between 120px and 600px', () => {
    const { container } = render(
      <FeedImageCarousel postKey={postKey} images={[A, B]} videos={[]} />
    );
    const [first, second] = Array.from(container.querySelectorAll('img'));
    const box = (img: HTMLImageElement): HTMLElement => img.parentElement as HTMLElement;

    // Not yet known: a muted square with a placeholder in it. Its place is held while it loads.
    expect(box(first).style.aspectRatio).toBe('1 / 1');
    expect(box(first).className).toContain('bg-muted');
    expect(box(first).querySelector('[data-slot="skeleton"]')).not.toBeNull();
    expect(box(first).className).toContain('min-h-[120px]');
    expect(box(first).className).toContain('max-h-[600px]');

    loads(first, 1200, 800);
    expect(box(first).style.aspectRatio).toBe('1200 / 800');
    expect(box(first).querySelector('[data-slot="skeleton"]')).toBeNull();
    expect(box(first).className).toContain('min-h-[120px]');
    expect(box(first).className).toContain('max-h-[600px]');
    // The other page is untouched by it.
    expect(box(second).style.aspectRatio).toBe('1 / 1');

    // A tall picture is held at 600px and a wide one at 120px by the same box: the picture covers it.
    loads(second, 1080, 1920);
    expect(box(second).style.aspectRatio).toBe('1080 / 1920');
    expect(box(second).className).toContain('min-h-[120px]');
    expect(box(second).className).toContain('max-h-[600px]');
    expect(second.className).toContain('object-cover');
    expect(second.className).toContain('size-full');
  });

  it('is as tall as the page shown, and takes the height of the page it comes to rest on', async () => {
    const { container } = render(
      <FeedImageCarousel postKey={postKey} images={[A, B]} videos={[]} />
    );
    const scroller = scrollerOf(container);
    // Nothing measured yet: as tall as its pages make it.
    expect(scroller.style.height).toBe('');

    pagesAre(300, 450);
    expect(scroller.style.height).toBe('300px');

    // Passing by is not arriving: resized under a finger, the Android WebView puts the scroll back to the start.
    swipeTo(scroller, 1);
    expect(scroller.style.height).toBe('300px');

    await act(async () => {
      await new Promise((resolve) => setTimeout(resolve, 300));
    });
    expect(scroller.style.height).toBe('450px');

    // The move is 250ms that decelerates, and nothing at all under reduced motion.
    const classes = scroller.className;
    expect(classes).toContain('transition-[height]');
    expect(classes).toContain('duration-250');
    expect(classes).toContain('ease-out');
    expect(classes).toContain('motion-reduce:transition-none');
    expect(classes).toContain('scroll-smooth');
    expect(classes).toContain('motion-reduce:scroll-auto');
  });

  it('without a ResizeObserver it is simply as tall as its pages', () => {
    vi.stubGlobal('ResizeObserver', undefined);
    const { container } = render(
      <FeedImageCarousel postKey={postKey} images={[A, B]} videos={[]} />
    );

    expect(scrollerOf(container).style.height).toBe('');
    expect(FakeResizeObserver.latest).toBeNull();
  });

  it('stays on the page at the same index when an image before it is blocked', () => {
    const { container, rerender } = render(
      <FeedImageCarousel postKey={postKey} images={[A, B, C, D]} videos={[]} />
    );
    const scroller = scrollerOf(container);
    swipeTo(scroller, 1);
    expect(position().textContent).toBe('2 / 4');

    rerender(<FeedImageCarousel postKey={postKey} images={[B, C, D]} videos={[]} />);

    expect(position().textContent).toBe('2 / 3');
    expect(screen.getByRole('img', { name: '2번째 이미지' })).toHaveProperty('src', C);
    expect(scrollTo).not.toHaveBeenCalled();
  });

  it('goes to the page that is now the last one when the one it was on is past the end', () => {
    const { container, rerender } = render(
      <FeedImageCarousel postKey={postKey} images={[A, B, C]} videos={[]} />
    );
    const scroller = scrollerOf(container);
    swipeTo(scroller, 2);
    expect(position().textContent).toBe('3 / 3');

    rerender(<FeedImageCarousel postKey={postKey} images={[B, C]} videos={[]} />);

    expect(position().textContent).toBe('2 / 2');
    expect(scrollTo).toHaveBeenCalledTimes(1);
    expect(scrollTo).toHaveBeenCalledWith({ left: 400 });
  });

  it('shows nothing once every image is blocked, and starts again from the first one', () => {
    const { container, rerender } = render(
      <FeedImageCarousel postKey={postKey} images={[A, B, C]} videos={[]} />
    );
    swipeTo(scrollerOf(container), 2);
    expect(position().textContent).toBe('3 / 3');

    rerender(<FeedImageCarousel postKey={postKey} images={[]} videos={[]} />);
    expect(container.firstChild).toBeNull();

    rerender(<FeedImageCarousel postKey={postKey} images={[A, B, C]} videos={[]} />);
    expect(position().textContent).toBe('1 / 3');
  });

  it('does not jump back to a page it was on before the list grew again', () => {
    const { container, rerender } = render(
      <FeedImageCarousel postKey={postKey} images={[A, B, C]} videos={[]} />
    );
    swipeTo(scrollerOf(container), 2);

    rerender(<FeedImageCarousel postKey={postKey} images={[A]} videos={[]} />);
    rerender(<FeedImageCarousel postKey={postKey} images={[A, B, C]} videos={[]} />);

    expect(position().textContent).toBe('1 / 3');
  });

  it('keeps the pages of one address apart when a post holds it twice', () => {
    // Two pages with one key would be one page to React, and it would say so here.
    const error = vi.spyOn(console, 'error').mockImplementation(() => undefined);
    render(<FeedImageCarousel postKey={postKey} images={[A, A, B]} videos={[]} />);

    expect(screen.getByRole('img', { name: '1번째 이미지' })).toHaveProperty('src', A);
    expect(screen.getByRole('img', { name: '2번째 이미지' })).toHaveProperty('src', A);
    expect(screen.getByRole('img', { name: '3번째 이미지' })).toHaveProperty('src', B);
    expect(error).not.toHaveBeenCalled();
  });

  it('asks for its pictures lazily and without a Referer, as the community CDNs need', () => {
    const { container } = render(
      <FeedImageCarousel
        postKey={postKey}
        images={[A, B]}
        videos={[video(EMBED, { thumbnailUrl: 'https://img.test/1.jpg' })]}
      />
    );

    const images = Array.from(container.querySelectorAll('img'));
    expect(images).toHaveLength(3);
    for (const img of images) {
      expect(img.getAttribute('loading')).toBe('lazy');
      expect(img.getAttribute('referrerpolicy')).toBe('no-referrer');
      expect(img.getAttribute('decoding')).toBe('async');
    }
  });

  it('a picture that fails says so where its place is kept, and offers to try again', () => {
    // Where a viewer opens on a tap, a picture is a button: a failed one must not be.
    const onOpenImage = vi.fn<(index: number) => void>();
    const { container } = render(
      <FeedImageCarousel postKey={postKey} images={[A, B]} videos={[]} onOpenImage={onOpenImage} />
    );
    const [first] = Array.from(container.querySelectorAll('img'));
    loads(first, 1200, 800);

    fireEvent.error(first);

    const alert = screen.getByRole('alert');
    expect(alert.textContent).toContain('이미지를 불러오지 못했습니다');
    const retry = within(alert).getByRole('button', { name: '다시 시도' });
    expect(retry.className).toContain('h-11');
    // The shape it had is kept, and no broken picture is shown in it.
    const kept = alert.parentElement as HTMLElement;
    expect(kept.style.aspectRatio).toBe('1200 / 800');
    expect(kept.className).toContain('bg-muted');
    expect(kept.querySelector('img')).toBeNull();
    // 다시 시도 is a button of its own, inside no other.
    expect(alert.closest('button')).toBeNull();
    expect(retry.closest('button')).toBe(retry);

    fireEvent.click(retry);

    // Trying again is not also a tap that opens the viewer.
    expect(onOpenImage).not.toHaveBeenCalled();

    const again = container.querySelector('img') as HTMLImageElement;
    expect(again).not.toBe(first);
    expect(again).toHaveProperty('src', A);
    expect(screen.queryByRole('alert')).toBeNull();
    expect(again.parentElement?.style.aspectRatio).toBe('1 / 1');
    loads(again, 1200, 800);
    // Loaded again, the picture is back to being what a tap opens: the button lies over it, holding nothing.
    const open = screen.getByRole('button', { name: '1번째 이미지' });
    expect(pageHolding(container, again).contains(open)).toBe(true);
    expect(open.childElementCount).toBe(0);
    // And nothing that is not phrasing content sits inside a button of the pager.
    expect(container.querySelectorAll('button :is(div, p, ul, ol, h1, h2, h3)')).toHaveLength(0);
  });

  it('keeps the WebView from selecting the media and from offering its own menu on a long press', () => {
    const { container } = render(
      <FeedImageCarousel postKey={postKey} images={[A, B]} videos={[]} onMore={vi.fn()} />
    );
    const media = area(container);

    expect(media.className).toContain('select-none');
    expect(media.className).toContain('[-webkit-touch-callout:none]');
    // fireEvent says false when the page kept the browser from its default.
    expect(fireEvent.contextMenu(pagesOf(container)[0])).toBe(false);
    expect(fireEvent.contextMenu(container.querySelector('img') as Element)).toBe(false);
    expect(fireEvent.contextMenu(more())).toBe(false);
  });

  describe('the long press', () => {
    beforeEach(() => {
      vi.useFakeTimers();
    });

    it('asks for the sheet after 500 ms on the page shown, and not before', () => {
      const onMore = vi.fn<(target: Target) => void>();
      const { container } = render(
        <FeedImageCarousel postKey={postKey} images={[A, B]} videos={[]} onMore={onMore} />
      );
      const page = pagesOf(container)[0];

      fireEvent.pointerDown(page, finger);
      act(() => vi.advanceTimersByTime(499));
      expect(onMore).not.toHaveBeenCalled();

      act(() => vi.advanceTimersByTime(1));
      expect(onMore).toHaveBeenCalledTimes(1);
      expect(onMore).toHaveBeenCalledWith({ url: A, kind: 'image' });
    });

    it('asks once for the page, however long the finger stays', () => {
      const onMore = vi.fn();
      const { container } = render(
        <FeedImageCarousel postKey={postKey} images={[A]} videos={[]} onMore={onMore} />
      );

      fireEvent.pointerDown(pagesOf(container)[0], finger);
      act(() => vi.advanceTimersByTime(5000));

      expect(onMore).toHaveBeenCalledTimes(1);
    });

    it('asks for the page that is shown, not the first one', () => {
      const onMore = vi.fn<(target: Target) => void>();
      const { container } = render(
        <FeedImageCarousel
          postKey={postKey}
          images={[A, B]}
          videos={[video('https://e.com/v.mp4')]}
          onMore={onMore}
        />
      );
      swipeTo(scrollerOf(container), 2);

      fireEvent.pointerDown(pagesOf(container)[2], finger);
      act(() => vi.advanceTimersByTime(500));

      expect(onMore).toHaveBeenCalledWith({ url: 'https://e.com/v.mp4', kind: 'video' });
    });

    it('is no long press when the pointer is let go first: that is a tap', () => {
      const onMore = vi.fn();
      const { container } = render(
        <FeedImageCarousel postKey={postKey} images={[A]} videos={[]} onMore={onMore} />
      );
      const page = pagesOf(container)[0];

      fireEvent.pointerDown(page, finger);
      act(() => vi.advanceTimersByTime(300));
      fireEvent.pointerUp(page, { pointerId: 7 });
      act(() => vi.advanceTimersByTime(1000));

      expect(onMore).not.toHaveBeenCalled();
    });

    it('is no long press when the browser takes the gesture away, as it does for a swipe', () => {
      const onMore = vi.fn();
      const { container } = render(
        <FeedImageCarousel postKey={postKey} images={[A]} videos={[]} onMore={onMore} />
      );
      const page = pagesOf(container)[0];

      fireEvent.pointerDown(page, finger);
      act(() => vi.advanceTimersByTime(200));
      fireEvent.pointerCancel(page, { pointerId: 7 });
      act(() => vi.advanceTimersByTime(1000));

      expect(onMore).not.toHaveBeenCalled();
    });

    it('is no long press once the pointer has moved more than about 10px', () => {
      const onMore = vi.fn();
      const { container } = render(
        <FeedImageCarousel postKey={postKey} images={[A, B]} videos={[]} onMore={onMore} />
      );
      const page = pagesOf(container)[0];

      fireEvent.pointerDown(page, finger);
      act(() => vi.advanceTimersByTime(200));
      fireEvent.pointerMove(page, { pointerId: 7, clientX: 115, clientY: 100 });
      act(() => vi.advanceTimersByTime(1000));

      expect(onMore).not.toHaveBeenCalled();
    });

    it('still counts as a press when the finger trembles a little', () => {
      const onMore = vi.fn();
      const { container } = render(
        <FeedImageCarousel postKey={postKey} images={[A]} videos={[]} onMore={onMore} />
      );
      const page = pagesOf(container)[0];

      fireEvent.pointerDown(page, finger);
      act(() => vi.advanceTimersByTime(200));
      fireEvent.pointerMove(page, { pointerId: 7, clientX: 106, clientY: 105 });
      act(() => vi.advanceTimersByTime(300));

      expect(onMore).toHaveBeenCalledTimes(1);
    });

    it('does not start on a slider: a thumb held still before a drag is not a press on the media', () => {
      const onMore = vi.fn();
      const { container } = render(
        <FeedImageCarousel postKey={postKey} images={[A]} videos={[]} onMore={onMore} />
      );
      const thumb = document.createElement('div');
      thumb.setAttribute('role', 'slider');
      pagesOf(container)[0].append(thumb);

      fireEvent.pointerDown(thumb, finger);
      act(() => vi.advanceTimersByTime(1000));

      expect(onMore).not.toHaveBeenCalled();
    });

    it('is for the first finger and the main button only', () => {
      const onMore = vi.fn();
      const { container } = render(
        <FeedImageCarousel postKey={postKey} images={[A]} videos={[]} onMore={onMore} />
      );
      const page = pagesOf(container)[0];

      fireEvent.pointerDown(page, { ...finger, isPrimary: false });
      fireEvent.pointerDown(page, { ...finger, button: 2 });
      act(() => vi.advanceTimersByTime(1000));

      expect(onMore).not.toHaveBeenCalled();
    });

    it('does nothing where the page offers no sheet', () => {
      const { container } = render(
        <FeedImageCarousel postKey={postKey} images={[A]} videos={[]} />
      );
      const page = pagesOf(container)[0];

      fireEvent.pointerDown(page, finger);
      act(() => vi.advanceTimersByTime(1000));

      expect(touchMove(page)).toBe(false);
    });

    it('letting go of a long press is not also a tap, and the next tap is one', () => {
      const onMore = vi.fn();
      const onOpenImage = vi.fn<(index: number) => void>();
      render(
        <FeedImageCarousel
          postKey={postKey}
          images={[A]}
          videos={[]}
          onMore={onMore}
          onOpenImage={onOpenImage}
        />
      );
      const picture = screen.getByRole('button', { name: '1번째 이미지' });

      fireEvent.pointerDown(picture, finger);
      act(() => vi.advanceTimersByTime(500));
      expect(onMore).toHaveBeenCalledTimes(1);
      release(picture);
      expect(onOpenImage).not.toHaveBeenCalled();

      fireEvent.pointerDown(picture, finger);
      release(picture);
      expect(onOpenImage).toHaveBeenCalledTimes(1);
      expect(onOpenImage).toHaveBeenCalledWith(0);
    });

    it('a click of the keyboard is never taken for how a long press ended', () => {
      const onMore = vi.fn();
      const onOpenImage = vi.fn<(index: number) => void>();
      render(
        <FeedImageCarousel
          postKey={postKey}
          images={[A]}
          videos={[]}
          onMore={onMore}
          onOpenImage={onOpenImage}
        />
      );
      const picture = screen.getByRole('button', { name: '1번째 이미지' });

      // A mouse that pressed long and was let go elsewhere: its click never came here.
      fireEvent.pointerDown(picture, { ...finger, pointerId: 1 });
      act(() => vi.advanceTimersByTime(500));
      fireEvent.pointerUp(picture, { pointerId: 1 });
      expect(onMore).toHaveBeenCalledTimes(1);

      // Enter on the picture: a click from no pointer at all, as Chromium sends it.
      fireEvent(
        picture,
        new PointerEvent('click', { bubbles: true, cancelable: true, pointerId: -1 })
      );
      fireEvent(picture, new MouseEvent('click', { bubbles: true, cancelable: true }));
      expect(onOpenImage).toHaveBeenCalledTimes(2);
    });

    it('keeps a finger that pressed long from starting a swipe', () => {
      const onMore = vi.fn();
      const { container } = render(
        <FeedImageCarousel postKey={postKey} images={[A, B]} videos={[]} onMore={onMore} />
      );
      const page = pagesOf(container)[0];

      fireEvent.pointerDown(page, finger);
      // Still free to become a swipe.
      expect(touchMove(page)).toBe(false);

      act(() => vi.advanceTimersByTime(500));
      expect(onMore).toHaveBeenCalledTimes(1);
      // Held long: a move now is not the start of a swipe.
      expect(touchMove(page)).toBe(true);

      // A new press is free again.
      fireEvent.pointerUp(page, { pointerId: 7 });
      fireEvent.pointerDown(page, finger);
      expect(touchMove(page)).toBe(false);
    });

    it('forgets a press it was still watching when the pager goes', () => {
      const onMore = vi.fn();
      const { container, unmount } = render(
        <FeedImageCarousel postKey={postKey} images={[A]} videos={[]} onMore={onMore} />
      );

      fireEvent.pointerDown(pagesOf(container)[0], finger);
      unmount();
      act(() => vi.advanceTimersByTime(1000));

      expect(onMore).not.toHaveBeenCalled();
    });
  });
});
