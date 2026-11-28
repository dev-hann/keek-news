// @vitest-environment jsdom
import { act, fireEvent, render, screen, within } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { VideoBlock } from '../../src/model/content_block';
import { videoId } from '../../src/model/video_id';
import { feedVideoPlaybackNotifier } from '../../src/provider/feed_video_playback_provider';
import { InlineVideoPlayer } from '../../src/widgets/inline_video_player';

const CLIP = videoId('humoruniv:7', 0);
const NEXT = videoId('humoruniv:7', 1);
/** A video no player of these tests has: naming it leaves the one a test left. */
const NOBODY = videoId('humoruniv:none', 0);

const clip = (extra: Partial<VideoBlock> = {}): VideoBlock => ({
  type: 'video',
  url: 'https://e.com/v.mp4',
  thumbnailUrl: 'https://e.com/v.jpg',
  ...extra,
});

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

/** What the document says is in full screen, and who was asked to go there or to leave. */
let fullscreenElement: Element | null;
const askedFullscreen: Element[] = [];
let leftFullscreen = 0;

/** A way in to the observer each player made, in the order they were made. */
const observers: ((visible: number) => void)[] = [];

class FakeIntersectionObserver {
  observe = vi.fn();
  disconnect = vi.fn();

  constructor(callback: (entries: { intersectionRatio: number }[]) => void) {
    observers.push((visible) => callback([{ intersectionRatio: visible }]));
  }
}

/** Says how much of the player `at` is on screen, as the observer it made would be told. */
function scrolled(at: number, visible: number): void {
  observers[at]?.(visible);
}

beforeEach(() => {
  plays = [];
  pauses = [];
  fullscreenElement = null;
  askedFullscreen.length = 0;
  leftFullscreen = 0;
  loads.length = 0;
  observers.length = 0;
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

  Object.defineProperty(Element.prototype, 'requestFullscreen', {
    configurable: true,
    value: function (this: Element) {
      askedFullscreen.push(this);
      return Promise.resolve();
    },
  });
  Object.defineProperty(document, 'fullscreenElement', {
    configurable: true,
    get: () => fullscreenElement,
  });
  Object.defineProperty(document, 'exitFullscreen', {
    configurable: true,
    value: () => {
      leftFullscreen += 1;
      return Promise.resolve();
    },
  });

  vi.stubGlobal('IntersectionObserver', FakeIntersectionObserver);
  vi.stubGlobal('Image', FakeImage);
});

afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
  delete (Element.prototype as { requestFullscreen?: unknown }).requestFullscreen;
  delete (document as { fullscreenElement?: unknown }).fullscreenElement;
  delete (document as { exitFullscreen?: unknown }).exitFullscreen;
});

/** The player itself: the one thing it renders. `at` tells the players apart when there are more. */
function stageOf(container: HTMLElement, at = 0): HTMLElement {
  return container.children[at] as HTMLElement;
}

function videoIn(stage: HTMLElement): HTMLVideoElement {
  const video = stage.querySelector('video');
  if (video === null) throw new Error('The stage has no video: it was not started, or it failed.');
  return video;
}

/** The layer that holds every control, and fades as a whole. */
function controlsOf(stage: HTMLElement): HTMLElement {
  const controls = stage.querySelector<HTMLElement>('.transition-opacity');
  if (controls === null) throw new Error('The stage has no controls.');
  return controls;
}

/** The classes of an element one by one: `text-white` is not `hover:text-white`, nor a disabled button's. */
const classes = (element: Element): string[] => element.className.split(/\s+/);

/** What the browser would have found out about the video. jsdom finds out nothing. */
function knows(
  video: HTMLVideoElement,
  about: { time?: number; duration?: number; loaded?: number }
): void {
  let time = about.time ?? 0;
  const duration = about.duration ?? Number.NaN;
  const loaded = about.loaded ?? 0;
  Object.defineProperty(video, 'currentTime', {
    configurable: true,
    get: () => time,
    set: (to: number) => {
      time = to;
    },
  });
  Object.defineProperty(video, 'duration', { configurable: true, get: () => duration });
  Object.defineProperty(video, 'buffered', {
    configurable: true,
    value: { length: loaded > 0 ? 1 : 0, start: () => 0, end: () => loaded },
  });
}

/** Brings a started video to where a browser has it: a frame drawn, playing, 5 of 31 seconds in, 20 seconds loaded. */
function playingAt(video: HTMLVideoElement): void {
  knows(video, { time: 5, duration: 31, loaded: 20 });
  fireEvent.durationChange(video);
  fireEvent.loadedData(video);
  fireEvent.play(video);
  fireEvent.playing(video);
  fireEvent.timeUpdate(video);
}

/** Taps 재생, the way a reader starts the video. */
function start(container: HTMLElement, at = 0): HTMLVideoElement {
  fireEvent.click(within(stageOf(container, at)).getByRole('button', { name: '재생' }));
  return videoIn(stageOf(container, at));
}

describe('InlineVideoPlayer', () => {
  it('asks for nothing of the video before the tap: only its poster, under 재생', async () => {
    const { container } = render(<InlineVideoPlayer id={CLIP} video={clip()} />);
    const stage = stageOf(container);

    expect(stage.querySelector('video')).toBeNull();
    expect(plays).toEqual([]);
    expect(loads.map((load) => [load.src, load.referrerPolicy])).toEqual([
      ['https://e.com/v.jpg', 'no-referrer'],
    ]);
    // A poster that has not come yet leaves the black stage and the button: never blank.
    expect(stage.querySelector('img')).toBeNull();

    const play = within(stage).getByRole('button', { name: '재생' });
    // The whole stage is the button.
    expect(classes(play)).toEqual(expect.arrayContaining(['absolute', 'inset-0']));
    const circle = play.querySelector('span')!;
    expect(classes(circle)).toContain('rounded-full');
    expect(classes(circle)).toContain('bg-black/40');
    expect(classes(circle)).toContain('size-16');
    expect(classes(circle)).toContain('text-white');
    const icon = circle.querySelector('svg')!;
    expect(icon.getAttribute('aria-hidden')).toBe('true');
    expect(icon.getAttribute('class')).toContain('size-10');

    await act(() => loads[0].onload?.());

    const poster = stage.querySelector('img')!;
    expect(poster.getAttribute('src')).toBe('https://e.com/v.jpg');
    expect(poster.getAttribute('referrerpolicy')).toBe('no-referrer');
    expect(classes(poster)).toContain('object-cover');
    expect(classes(stage)).toContain('bg-black');
    expect(stage.querySelector('video')).toBeNull();
  });

  it('has no poster to show without an address for one, and asks for none', () => {
    const { container } = render(
      <InlineVideoPlayer id={CLIP} video={clip({ thumbnailUrl: undefined })} />
    );
    const stage = stageOf(container);

    expect(stage.querySelector('img')).toBeNull();
    expect(loads).toEqual([]);
    expect(within(stage).getByRole('button', { name: '재생' })).toBeTruthy();
    expect(classes(stage)).toContain('bg-black');
  });

  it('holds the place: 16 / 9, or the shape the block knows', () => {
    const { container, rerender } = render(<InlineVideoPlayer id={CLIP} video={clip()} />);
    expect(stageOf(container).style.aspectRatio).toBe('16 / 9');

    rerender(<InlineVideoPlayer id={CLIP} video={clip({ width: 720, height: 1280 })} />);
    expect(stageOf(container).style.aspectRatio).toBe('720 / 1280');

    // One of the two is not a shape.
    rerender(<InlineVideoPlayer id={CLIP} video={clip({ width: 720 })} />);
    expect(stageOf(container).style.aspectRatio).toBe('16 / 9');
  });

  it('keeps the shape it reserved once the video plays, of whatever shape the video is', () => {
    // A card does not move when a video starts: the video is letterboxed inside the stage.
    const { container } = render(<InlineVideoPlayer id={CLIP} video={clip()} />);
    const video = start(container);

    Object.defineProperty(video, 'videoWidth', { configurable: true, value: 720 });
    Object.defineProperty(video, 'videoHeight', { configurable: true, value: 1280 });
    fireEvent.loadedMetadata(video);
    fireEvent.play(video);

    expect(stageOf(container).style.aspectRatio).toBe('16 / 9');
  });

  it('the tap mounts the video muted, looping and inline under controls of its own, and names it', () => {
    const { container } = render(<InlineVideoPlayer id={CLIP} video={clip()} />);
    const stage = stageOf(container);
    const video = start(container);

    expect(video.getAttribute('src')).toBe('https://e.com/v.mp4');
    expect(video.muted).toBe(true);
    expect(video.getAttribute('preload')).toBe('auto');
    for (const attribute of [
      'playsinline',
      'loop',
      'disablepictureinpicture',
      'disableremoteplayback',
    ]) {
      expect(video.hasAttribute(attribute)).toBe(true);
    }
    expect(video.hasAttribute('controls')).toBe(false);
    // The whole video inside the stage, whatever shape either has.
    expect(classes(video)).toEqual(
      expect.arrayContaining(['object-contain', 'absolute', 'inset-0'])
    );
    expect(plays).toEqual([video]);
    expect(pauses).toEqual([]);
    expect(feedVideoPlaybackNotifier().getState()).toBe(CLIP);
    // The big 재생 of the poster is gone: the controls took its place.
    expect(stage.querySelector('.size-16')).toBeNull();
    expect(loads.map((load) => load.src)).toEqual(['https://e.com/v.jpg']);
  });

  it('has the controls, each with a Korean name and a hidden icon, white on the black stage', () => {
    const { container } = render(<InlineVideoPlayer id={CLIP} video={clip()} />);
    const stage = stageOf(container);
    const video = start(container);
    playingAt(video);

    const pauseButtons = within(stage).getAllByRole('button', { name: '일시정지' });
    expect(pauseButtons).toHaveLength(2);
    expect(classes(pauseButtons[0])).toContain('size-16');
    expect(classes(pauseButtons[0])).toContain('rounded-full');
    expect(classes(pauseButtons[1])).toContain('size-11');
    const slider = within(stage).getByRole('slider', { name: '재생 위치' });
    expect(classes(slider.parentElement!)).toContain('h-11');
    expect(classes(within(stage).getByRole('button', { name: '음소거 해제' }))).toContain(
      'size-11'
    );
    expect(classes(within(stage).getByRole('button', { name: '전체 화면' }))).toContain('size-11');
    expect(within(stage).queryByRole('button', { name: '재생' })).toBeNull();
    expect(within(stage).queryByRole('status')).toBeNull();

    for (const button of within(stage).getAllByRole('button')) {
      const icons = button.querySelectorAll('svg');
      expect(icons).toHaveLength(1);
      expect(icons[0].getAttribute('aria-hidden')).toBe('true');
      expect(classes(button)).toContain('text-white');
      // Shown: each takes its own tap.
      expect(classes(button)).toContain('pointer-events-auto');
    }
    // The bar is over a black gradient.
    const bar = slider.closest('.bg-linear-to-b')!;
    expect(classes(bar)).toContain('from-transparent');
    expect(classes(bar)).toContain('to-black/70');
  });

  it('says how far the video is from what the browser found, once the browser found it', () => {
    const { container } = render(<InlineVideoPlayer id={CLIP} video={clip()} />);
    const video = start(container);

    expect(screen.getByText('0:00 / 0:00')).toBeTruthy();
    expect(screen.getByRole('slider', { name: '재생 위치' })).toHaveProperty('disabled', true);

    playingAt(video);

    expect(screen.getByText('0:05 / 0:31')).toBeTruthy();
    expect(screen.getByRole('slider', { name: '재생 위치' })).toHaveProperty('value', '5');
  });

  it('scrubbing moves the video, and the time follows at once', () => {
    const { container } = render(<InlineVideoPlayer id={CLIP} video={clip()} />);
    const video = start(container);
    playingAt(video);

    fireEvent.change(screen.getByRole('slider', { name: '재생 위치' }), {
      target: { value: '12' },
    });

    expect(video.currentTime).toBe(12);
    expect(screen.getByText('0:12 / 0:31')).toBeTruthy();
  });

  it('starts muted, and the mute button turns the sound on and off again', () => {
    const { container } = render(<InlineVideoPlayer id={CLIP} video={clip()} />);
    const video = start(container);
    playingAt(video);
    expect(video.muted).toBe(true);

    fireEvent.click(screen.getByRole('button', { name: '음소거 해제' }));

    expect(video.muted).toBe(false);
    expect(screen.queryByRole('button', { name: '음소거 해제' })).toBeNull();

    fireEvent.click(screen.getByRole('button', { name: '음소거' }));

    expect(video.muted).toBe(true);
    expect(screen.getByRole('button', { name: '음소거 해제' })).toBeTruthy();
  });

  it('asks for full screen on its own element, where the controls stay, and follows the document back', () => {
    const { container } = render(<InlineVideoPlayer id={CLIP} video={clip()} />);
    const stage = stageOf(container);
    const video = start(container);
    playingAt(video);
    expect(classes(stage)).toContain('[&:fullscreen]:fixed');
    expect(classes(stage)).toContain('[&:fullscreen]:inset-0');

    fireEvent.click(screen.getByRole('button', { name: '전체 화면' }));

    expect(askedFullscreen).toEqual([stage]);
    // Nothing is mounted again: the same load goes on.
    expect(videoIn(stage)).toBe(video);
    expect(plays).toEqual([video]);

    // The document says the request went through.
    fullscreenElement = stage;
    fireEvent(document, new Event('fullscreenchange'));
    expect(screen.getByRole('button', { name: '전체 화면 종료' })).toBeTruthy();

    fireEvent.click(screen.getByRole('button', { name: '전체 화면 종료' }));
    expect(leftFullscreen).toBe(1);

    // What the shell's system Back comes to: the document leaves full screen, unasked by the player.
    fullscreenElement = null;
    fireEvent(document, new Event('fullscreenchange'));
    expect(screen.getByRole('button', { name: '전체 화면' })).toBeTruthy();
    expect(videoIn(stage)).toBe(video);
  });

  it('is not in full screen when the document has something else there', () => {
    const { container } = render(<InlineVideoPlayer id={CLIP} video={clip()} />);
    const video = start(container);
    playingAt(video);

    fullscreenElement = document.body;
    fireEvent(document, new Event('fullscreenchange'));

    expect(screen.getByRole('button', { name: '전체 화면' })).toBeTruthy();
  });

  it('offers no full screen where the document cannot', () => {
    delete (Element.prototype as { requestFullscreen?: unknown }).requestFullscreen;
    const { container } = render(<InlineVideoPlayer id={CLIP} video={clip()} />);
    const video = start(container);
    playingAt(video);

    const stage = stageOf(container);
    expect(within(stage).queryByRole('button', { name: '전체 화면' })).toBeNull();
    expect(within(stage).getByRole('button', { name: '음소거 해제' })).toBeTruthy();
  });

  it('hides the controls 3 seconds into playing, and brings them back with a tap', () => {
    vi.useFakeTimers();
    const { container } = render(<InlineVideoPlayer id={CLIP} video={clip()} />);
    const stage = stageOf(container);
    const video = start(container);
    playingAt(video);
    const controls = controlsOf(stage);

    expect(classes(controls)).toContain('opacity-100');
    expect(classes(controls)).toContain('duration-250');
    expect(classes(controls)).toContain('motion-reduce:transition-none');
    act(() => vi.advanceTimersByTime(2999));
    expect(classes(controls)).toContain('opacity-100');

    act(() => vi.advanceTimersByTime(1));
    expect(classes(controls)).toContain('opacity-0');
    for (const control of within(controls).getAllByRole('button')) {
      expect(control).toHaveProperty('tabIndex', -1);
      expect(classes(control)).toContain('pointer-events-none');
    }
    expect(screen.getByRole('slider', { name: '재생 위치' })).toHaveProperty('tabIndex', -1);
    // What is left takes the tap, and says what it does.
    const show = screen.getByRole('button', { name: '컨트롤 표시' });
    expect(classes(show)).toEqual(expect.arrayContaining(['absolute', 'inset-0']));

    fireEvent.click(show);
    expect(classes(controls)).toContain('opacity-100');
    expect(screen.queryByRole('button', { name: '컨트롤 표시' })).toBeNull();
    // Showing them is not also a play or a pause.
    expect(plays).toEqual([video]);
    expect(pauses).toEqual([]);

    act(() => vi.advanceTimersByTime(3000));
    expect(classes(controls)).toContain('opacity-0');
  });

  it('a tap on the stage shows hidden controls and hides shown ones: it never plays or pauses', () => {
    vi.useFakeTimers();
    const { container } = render(<InlineVideoPlayer id={CLIP} video={clip()} />);
    const stage = stageOf(container);
    const video = start(container);
    playingAt(video);

    // Shown: the tap hides them, and the video plays on.
    fireEvent.click(video);
    expect(classes(controlsOf(stage))).toContain('opacity-0');
    expect(pauses).toEqual([]);
    expect(plays).toEqual([video]);

    // Hidden: the same tap shows them.
    fireEvent.click(video);
    expect(classes(controlsOf(stage))).toContain('opacity-100');
    expect(pauses).toEqual([]);

    // Playing on, they go by themselves again.
    fireEvent.play(video);
    act(() => vi.advanceTimersByTime(3000));
    expect(classes(controlsOf(stage))).toContain('opacity-0');

    // The buttons, not the stage, play and pause.
    fireEvent.click(screen.getByRole('button', { name: '컨트롤 표시' }));
    fireEvent.click(within(stage).getAllByRole('button', { name: '일시정지' })[0]);
    expect(pauses).toEqual([video]);
    fireEvent.pause(video);
    // In the middle and in the bar: both say 재생 again.
    expect(within(stage).getAllByRole('button', { name: '재생' })).toHaveLength(2);
  });

  it('a control answers its own click only', () => {
    const { container } = render(<InlineVideoPlayer id={CLIP} video={clip()} />);
    const video = start(container);
    playingAt(video);

    fireEvent.click(within(stageOf(container)).getAllByRole('button', { name: '일시정지' })[0]);

    expect(pauses).toEqual([video]);
    fireEvent.pause(video);
    fireEvent.click(within(stageOf(container)).getAllByRole('button', { name: '재생' })[0]);
    expect(plays).toEqual([video, video]);
  });

  it('a reader that reaches a hidden control gets the controls shown too, and the 3 seconds count again', () => {
    vi.useFakeTimers();
    const { container } = render(<InlineVideoPlayer id={CLIP} video={clip()} />);
    const stage = stageOf(container);
    const video = start(container);
    playingAt(video);
    act(() => vi.advanceTimersByTime(3000));
    expect(classes(controlsOf(stage))).toContain('opacity-0');

    // As a screen reader does: a click straight on the control, with nothing shown.
    fireEvent.click(screen.getByRole('button', { name: '음소거 해제' }));

    expect(video.muted).toBe(false);
    expect(classes(controlsOf(stage))).toContain('opacity-100');
    act(() => vi.advanceTimersByTime(2999));
    expect(classes(controlsOf(stage))).toContain('opacity-100');
    act(() => vi.advanceTimersByTime(1));
    expect(classes(controlsOf(stage))).toContain('opacity-0');
  });

  it('shows the controls again when the video pauses', () => {
    vi.useFakeTimers();
    const { container } = render(<InlineVideoPlayer id={CLIP} video={clip()} />);
    const stage = stageOf(container);
    const video = start(container);
    playingAt(video);
    act(() => vi.advanceTimersByTime(3000));
    expect(classes(controlsOf(stage))).toContain('opacity-0');

    fireEvent.pause(video);

    expect(classes(controlsOf(stage))).toContain('opacity-100');
    expect(within(stage).getAllByRole('button', { name: '재생' })).toHaveLength(2);
  });

  it('does not hide the controls under a keyboard focus, and counts again once it left', () => {
    vi.useFakeTimers();
    const { container } = render(<InlineVideoPlayer id={CLIP} video={clip()} />);
    const stage = stageOf(container);
    const video = start(container);
    playingAt(video);
    const controls = controlsOf(stage);
    const keyboardFocus = vi
      .spyOn(controls, 'matches')
      .mockImplementation((selector) => selector === ':has(:focus-visible)');

    act(() => vi.advanceTimersByTime(3000));
    expect(classes(controls)).toContain('opacity-100');

    keyboardFocus.mockRestore();
    act(() => vi.advanceTimersByTime(3000));
    expect(classes(controls)).toContain('opacity-100');

    // The 3 seconds start when the focus leaves, not while it stayed.
    fireEvent.focusOut(controls, { relatedTarget: document.body });
    act(() => vi.advanceTimersByTime(2999));
    expect(classes(controls)).toContain('opacity-100');
    act(() => vi.advanceTimersByTime(1));
    expect(classes(controls)).toContain('opacity-0');
  });

  it('a clip the site made of a GIF has 재생 and 일시정지, and nothing that would do nothing', () => {
    const { container } = render(
      <InlineVideoPlayer id={CLIP} video={clip({ isGifConversion: true })} />
    );
    const stage = stageOf(container);
    const video = start(container);
    playingAt(video);

    expect(
      within(stage)
        .getAllByRole('button')
        .map((button) => button.getAttribute('aria-label'))
    ).toEqual(['일시정지']);
    expect(within(stage).queryByRole('slider')).toBeNull();
    expect(within(stage).queryByText('0:05 / 0:31')).toBeNull();

    fireEvent.click(within(stage).getByRole('button', { name: '일시정지' }));

    expect(pauses).toEqual([video]);
    fireEvent.pause(video);
    expect(within(stage).getByRole('button', { name: '재생' })).toBeTruthy();
  });

  it('pauses when another video is named, and loads no more until it is its turn again', () => {
    const { container } = render(
      <>
        <InlineVideoPlayer id={CLIP} video={clip()} />
        <InlineVideoPlayer id={NEXT} video={clip({ url: 'https://e.com/w.mp4' })} />
      </>
    );
    const first = start(container, 0);
    fireEvent.play(first);
    const second = start(container, 1);

    expect(plays).toEqual([first, second]);
    expect(pauses).toEqual([first]);
    expect(feedVideoPlaybackNotifier().getState()).toBe(NEXT);
    expect(first.getAttribute('preload')).toBe('none');
    expect(second.getAttribute('preload')).toBe('auto');
    // The same load is kept: nothing is asked for again.
    expect(videoIn(stageOf(container, 0))).toBe(first);

    fireEvent.pause(first);
    fireEvent.click(within(stageOf(container, 0)).getAllByRole('button', { name: '재생' })[0]);

    expect(plays).toEqual([first, second, first]);
    expect(pauses).toEqual([first, second]);
    expect(first.getAttribute('preload')).toBe('auto');
    expect(second.getAttribute('preload')).toBe('none');
    expect(feedVideoPlaybackNotifier().getState()).toBe(CLIP);
  });

  it('pauses when less than 40 % of it is on screen, and keeps what it loaded', () => {
    const { container } = render(
      <>
        <InlineVideoPlayer id={CLIP} video={clip()} />
        <InlineVideoPlayer id={NEXT} video={clip({ url: 'https://e.com/w.mp4' })} />
      </>
    );
    const video = start(container, 0);
    playingAt(video);
    const stage = stageOf(container, 0);

    act(() => scrolled(0, 0.4));
    expect(pauses).toEqual([]);
    act(() => scrolled(0, 0.39));
    expect(pauses).toEqual([video]);
    // Paused, not unloaded: the video is where it was, with what it had.
    expect(videoIn(stage)).toBe(video);
    expect(video.currentTime).toBe(5);
    expect(video.getAttribute('preload')).toBe('auto');
    act(() => scrolled(0, 0));
    // Nothing more to pause.
    expect(pauses).toEqual([video]);
    // The other player was not started: however little of it is on screen, nothing is paused.
    act(() => scrolled(1, 0));
    expect(pauses).toEqual([video]);
  });

  it('works where the document has no IntersectionObserver', () => {
    vi.unstubAllGlobals();
    const { container } = render(<InlineVideoPlayer id={CLIP} video={clip()} />);
    const video = start(container);
    playingAt(video);

    expect(plays).toEqual([video]);
    expect(screen.getByText('0:05 / 0:31')).toBeTruthy();
  });

  it('shows a buffering indicator from the tap until the video plays, and whenever the data runs out', () => {
    const { container } = render(<InlineVideoPlayer id={CLIP} video={clip()} />);
    const stage = stageOf(container);
    const video = start(container);

    const status = () => within(stage).getByRole('status');
    expect(status().textContent).toBe('동영상 불러오는 중');
    const spinner = status().querySelector('svg')!;
    expect(spinner.getAttribute('aria-hidden')).toBe('true');
    expect(spinner.getAttribute('class')).toContain('animate-spin');
    expect(spinner.getAttribute('class')).toContain('motion-reduce:animate-none');

    fireEvent.play(video);
    expect(status()).toBeTruthy();
    fireEvent.playing(video);
    expect(within(stage).queryByRole('status')).toBeNull();

    fireEvent.waiting(video);
    expect(status()).toBeTruthy();
    fireEvent.playing(video);
    expect(within(stage).queryByRole('status')).toBeNull();

    fireEvent.stalled(video);
    expect(status()).toBeTruthy();

    // Paused, it is waiting for nothing, whatever the browser says of its loading.
    fireEvent.click(within(stage).getAllByRole('button', { name: '일시정지' })[0]);
    fireEvent.pause(video);
    expect(within(stage).queryByRole('status')).toBeNull();
    fireEvent.stalled(video);
    expect(within(stage).queryByRole('status')).toBeNull();

    fireEvent.click(within(stage).getAllByRole('button', { name: '재생' })[0]);
    fireEvent.play(video);
    fireEvent.waiting(video);
    expect(status()).toBeTruthy();
  });

  it('shows how far the video is loaded as the browser reports it', () => {
    const { container } = render(<InlineVideoPlayer id={CLIP} video={clip()} />);
    const video = start(container);
    playingAt(video);
    const loaded = () =>
      screen.getByRole('slider', { name: '재생 위치' }).nextElementSibling!
        .children[0] as HTMLElement;
    expect(parseFloat(loaded().style.width)).toBeCloseTo((20 / 31) * 100);

    knows(video, { time: 5, duration: 31, loaded: 10 });
    fireEvent.progress(video);

    expect(parseFloat(loaded().style.width)).toBeCloseTo((10 / 31) * 100);
  });

  it('keeps the poster until the first frame, then lets the video cover it; a stall keeps the frame', async () => {
    const { container } = render(<InlineVideoPlayer id={CLIP} video={clip()} />);
    const stage = stageOf(container);
    await act(() => loads[0].onload?.());
    const poster = stage.querySelector('img')!;
    const video = start(container);
    expect(classes(video)).toContain('opacity-0');
    expect(poster.classList.contains('hidden')).toBe(false);

    // The first frame: the video is still loading its way into playing.
    fireEvent.loadedData(video);

    expect(classes(video)).not.toContain('opacity-0');
    expect(poster.classList.contains('hidden')).toBe(true);

    fireEvent.waiting(video);
    expect(classes(video)).not.toContain('opacity-0');
    expect(within(stage).getByRole('status')).toBeTruthy();
  });

  it('says when the video cannot be loaded, over its poster, and a tap loads it again', async () => {
    const { container } = render(<InlineVideoPlayer id={CLIP} video={clip()} />);
    const stage = stageOf(container);
    await act(() => loads[0].onload?.());
    const video = start(container);
    playingAt(video);
    const poster = stage.querySelector('img')!;

    fireEvent.error(video);

    const alert = within(stage).getByRole('alert');
    expect(alert.textContent).toContain('동영상을 불러올 수 없습니다');
    expect(alert.textContent).toContain('탭하여 재시도');
    expect(alert.querySelector('svg')!.getAttribute('aria-hidden')).toBe('true');
    expect(stage.querySelector('video')).toBeNull();
    expect(poster.isConnected).toBe(true);
    expect(poster.classList.contains('hidden')).toBe(false);
    expect(within(stage).queryByRole('status')).toBeNull();
    expect(within(stage).queryByRole('button', { name: '일시정지' })).toBeNull();
    expect(within(stage).queryByRole('slider')).toBeNull();

    // Another video took its turn meanwhile.
    act(() => feedVideoPlaybackNotifier().setActive(NOBODY));

    // The whole stage is the tap.
    fireEvent.click(within(stage).getByRole('button', { name: '탭하여 재시도' }));
    expect(plays).toHaveLength(2);

    const again = videoIn(stage);
    expect(again).not.toBe(video);
    expect(plays[1]).toBe(again);
    expect(feedVideoPlaybackNotifier().getState()).toBe(CLIP);
    expect(within(stage).queryByRole('alert')).toBeNull();
    expect(within(stage).getByRole('status')).toBeTruthy();
    expect(within(stage).getByRole('button', { name: '재생' })).toBeTruthy();
  });

  it('plays at once when it was opened for this video, without the 재생 step', () => {
    const { container } = render(<InlineVideoPlayer id={CLIP} video={clip()} autoStart />);
    const stage = stageOf(container);
    const video = videoIn(stage);

    expect(plays).toEqual([video]);
    expect(feedVideoPlaybackNotifier().getState()).toBe(CLIP);
    expect(stage.querySelector('.size-16')).toBeNull();
    expect(within(stage).getAllByRole('button', { name: '재생' })).toHaveLength(1);
    expect(within(stage).getByRole('status')).toBeTruthy();
  });

  it('starts over when the same player comes to show another video', () => {
    const { container, rerender } = render(<InlineVideoPlayer id={CLIP} video={clip()} />);
    const before = start(container);
    playingAt(before);

    rerender(<InlineVideoPlayer id={CLIP} video={clip({ url: 'https://e.com/w.mp4' })} />);

    const stage = stageOf(container);
    expect(stage.querySelector('video')).toBeNull();
    expect(stage.querySelector('.size-16')).toBeTruthy();
    expect(within(stage).getByRole('button', { name: '재생' })).toBeTruthy();
    fireEvent.click(within(stage).getByRole('button', { name: '재생' }));
    expect(videoIn(stage).getAttribute('src')).toBe('https://e.com/w.mp4');
  });

  it('keeps its centre button above the bar, and the bar to a row of buttons with the scrub in the padding over it', () => {
    // Seen on the emulator's WebView: the bar's gradient covered the lower half of a card's 232px stage,
    // and took the taps meant for the centre button.
    const { container } = render(<InlineVideoPlayer id={CLIP} video={clip()} />);
    const video = start(container);
    playingAt(video);

    const centre = container.querySelector('.size-16');
    expect(centre?.tagName).toBe('BUTTON');
    expect(classes(centre)).toContain('z-10');

    const bar = container.querySelector('.bg-linear-to-b');
    expect(classes(bar)).not.toContain('flex-col');
    const scrub = bar?.querySelector('input[type="range"]')?.parentElement;
    expect(classes(scrub)).toEqual(expect.arrayContaining(['absolute', 'bottom-12', 'h-11']));
  });
});
