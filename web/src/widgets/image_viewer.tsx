import {
  ChevronLeft,
  ChevronRight,
  ImageOff,
  MoreHorizontal,
  X,
  ZoomIn,
  ZoomOut,
} from 'lucide-react';
import {
  useCallback,
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
  type PointerEvent as ReactPointerEvent,
  type ReactNode,
  type RefObject,
  type SyntheticEvent,
  type UIEvent,
} from 'react';
import { createPortal } from 'react-dom';
import { cn } from 'cn';
import { Button } from '../components/ui/button';
import { Skeleton } from '../components/ui/skeleton';
import { imageTarget, type MediaTarget } from '../model/media_target';
import { dialogClosed, dialogOpened, holdsFocus } from '../utils/dialog_stack';
import {
  HOLD_SLOP,
  IDENTITY,
  distance,
  fittedSize,
  isDoubleTap,
  isHorizontal,
  isLongImage,
  pageAfterDrag,
  pan,
  pinch,
  releaseSpeed,
  toTransform,
  zoomCentre,
  zoomStep,
  type Box,
  type Point,
  type Size,
  type Zoom,
} from '../utils/pinch_zoom';
import { useImageLoader, type LoadState } from '../utils/use_image_loader';
import { useHistoryBack } from '../utils/use_history_back';

/** What can take the focus inside the viewer. */
const FOCUSABLE = 'a[href], button:not([disabled]), [tabindex]:not([tabindex="-1"])';

/** A press held this long, in ms, is a long-press. */
const LONG_PRESS_MS = 500;

/**
 * A drag on a picture at 1x that began up or down becomes the viewer's own
 * only once it went this far sideways, in px: until then the browser may be
 * about to page the picture itself.
 */
const RESCUE_DISTANCE = 24;

/** Over everything, on black, inside the safe area. */
const FRAME =
  'fixed inset-0 z-50 flex flex-col bg-black pt-[env(safe-area-inset-top)] pb-[env(safe-area-inset-bottom)] select-none [-webkit-touch-callout:none]';

/** Pages side by side: the browser's own scrolling snaps from one to the next. */
const PAGER =
  'h-full w-full snap-x snap-mandatory overflow-x-auto overscroll-contain scroll-smooth motion-reduce:scroll-auto [scrollbar-width:none]';

/**
 * One page, as wide as the viewer: its picture in the middle, and nothing of
 * it beyond the page once zoomed. A fling is stopped at the next page: one
 * swipe is one image.
 */
const PAGE =
  'relative grid h-full w-full shrink-0 snap-center snap-always place-items-center overflow-hidden';

/** A picture that zooms: as large as fits. Its touch-action goes with its zoom, see the page. */
const PICTURE =
  'max-h-full max-w-full min-h-0 min-w-0 origin-top-left object-contain transition-transform duration-250 ease-out motion-reduce:transition-none';

/** A long picture: as wide as the viewer, read by scrolling it. */
const LONG_PICTURE = 'h-full w-full overflow-y-auto overscroll-contain [scrollbar-width:none]';

/** Room after a long picture, so that the position and the buttons never cover its end. */
const LONG_PICTURE_END = 'h-16';

/** The buttons and the position, over whatever is shown. */
const CHROME_BUTTON = 'pointer-events-auto size-11 rounded-full bg-black/60 text-white';
const CHROME_POSITION =
  'rounded-full bg-black/60 px-3 py-1 text-sm font-medium text-white tabular-nums';

interface ImageViewerProps {
  /** The images to page through, in order. Blocked ones are left out before this is given. */
  images: string[];
  /** The image shown first. */
  initialIndex: number;
  open: boolean;
  /** The viewer asks with it to be closed: the page sets `open` to false. */
  onClose: () => void;
  /** Opens the media action sheet for an image: a long-press on it, or its ⋯ button. */
  onMore?: (target: MediaTarget) => void;
}

/**
 * The images of a post full screen, one at a time. The page only sets `open`
 * to false when `onClose` runs: system Back does that too, before it can
 * leave the page. A picture blocked meanwhile leaves, and the viewer closes
 * itself when nothing is left to show.
 */
export function ImageViewer({ images, initialIndex, open, onClose, onMore }: ImageViewerProps) {
  const showing = open && images.length > 0;
  const requestClose = useHistoryBack(showing, onClose);

  const close = useRef(onClose);
  useEffect(() => {
    close.current = onClose;
  });

  // Opened with nothing to show, or emptied while open: the page is asked to close it,
  // which takes the entry of the viewer off the history too.
  useEffect(() => {
    if (open && images.length === 0) close.current();
  }, [images.length, open]);

  if (!showing) return null;
  return (
    <OpenViewer
      images={images}
      initialIndex={initialIndex}
      requestClose={requestClose}
      onMore={onMore}
    />
  );
}

/** What a page found about its picture: how loading it stands, and its width over height once known. */
interface PageInfo {
  state: LoadState;
  aspect: number | null;
}

/** A page's picture, as its gestures need to know it. */
interface Picture {
  url: string;
  aspect: number | null;
  /** Long: shown at the width of the viewer and scrolled, never zoomed. */
  long: boolean;
}

/** A picture shown zoomed: which one, how, and whether what moves it shows at once. */
interface View {
  url: string;
  zoom: Zoom;
  /** A pointer is moving it: it follows at once, with nothing easing along behind. */
  instant: boolean;
}

type PagePointerEvent = ReactPointerEvent<HTMLDivElement>;

interface PageHandlers {
  onPointerDown: (event: PagePointerEvent) => void;
  onPointerMove: (event: PagePointerEvent) => void;
  onPointerUp: (event: PagePointerEvent) => void;
  onPointerCancel: (event: PagePointerEvent) => void;
}

/** What the pointers on a page are doing. */
type GestureKind =
  /** Nothing of the viewer's: the browser scrolls, or the pointer is off the picture. */
  | 'off'
  /** Down and still: a tap, a double-tap or a long-press so far. */
  | 'press'
  /** A drag on a picture at 1x that began up or down. The browser leaves such a one alone, so it may yet page. */
  | 'rescuable'
  /** Dragging the pager. */
  | 'swipe'
  /** Dragging a zoomed picture. */
  | 'pan'
  /** Two pointers zooming. */
  | 'pinch'
  /** The long-press fired: the rest of the gesture is not the viewer's. */
  | 'held';

interface Swipe {
  /** The page nearest when the drag began, and where the pager's left edge was then, in px. */
  page: number;
  from: number;
  /** Where the pointer was when the pager began to follow it. */
  pointer: Point;
  /** How it went since: `[time, how far the pager is from where it started]`, the earliest first. */
  path: Array<[number, number]>;
}

interface Drag {
  zoom: Zoom;
  /** A pan: where the pointer was. A pinch: where both pointers were. From the corner of the picture's box. */
  from: Point;
  pair: [Point, Point] | null;
}

interface Gesture {
  /** The page the pointers went down on. */
  slot: HTMLDivElement;
  url: string;
  kind: GestureKind;
  pointers: Map<number, Point>;
  /** Where the first pointer went down. */
  start: Point;
  doubleTap: boolean;
  timer: ReturnType<typeof setTimeout> | null;
  swipe: Swipe | null;
  drag: Drag | null;
}

function atPage(at: number, count: number): number {
  return Math.min(count - 1, Math.max(0, at));
}

function pointOf(event: PagePointerEvent): Point {
  return { x: event.clientX, y: event.clientY };
}

/** A pointer position, told from the top left corner of a box. */
function inBox(point: Point, box: Box): Point {
  return { x: point.x - box.x, y: point.y - box.y };
}

/**
 * Touches and clicks stay in the viewer. The page behind listens for touches
 * on the window (its pull to refresh), and a tap inside the viewer would
 * reach, through React, whatever rendered the viewer.
 */
function stay(event: SyntheticEvent): void {
  event.stopPropagation();
}

/**
 * The finger that made a long-press is lifted, and the browser goes on to
 * click where the finger was, whatever is under it by then: a sheet the
 * long-press opened would be closed by its scrim at once. The click is the
 * touch's default: it does not come once the touch is ended without one.
 */
function endTouch(event: SyntheticEvent, longPressLifted: RefObject<boolean>): void {
  stay(event);
  if (!longPressLifted.current) return;
  longPressLifted.current = false;
  event.preventDefault();
}

/**
 * The viewer while it is open. It goes into the document when the viewer
 * opens and out of it when the viewer closes, so each time it opens it starts
 * over: on `initialIndex`, at 1x.
 */
function OpenViewer({
  images,
  initialIndex,
  requestClose,
  onMore,
}: {
  images: string[];
  initialIndex: number;
  requestClose: () => void;
  onMore?: (target: MediaTarget) => void;
}) {
  const panel = useRef<HTMLDivElement>(null);
  const pager = useRef<HTMLDivElement>(null);
  const closeButton = useRef<HTMLButtonElement>(null);
  const gesture = useRef<Gesture | null>(null);
  const lastTap = useRef<{ time: number; point: Point } | null>(null);
  /** A long-press just ended by the finger lifting: the touch that ends with it is not to go on as a click. */
  const longPressLifted = useRef(false);

  // The page it opens on, once: the pager is put there before anything is seen.
  const [first] = useState(() => atPage(initialIndex, images.length));
  // A picture that leaves takes its page with it: the page shown stays where it is, or is the last one.
  const [index, setIndex] = useState(first);
  const current = atPage(index, images.length);
  const url = images[current];
  const [view, setView] = useState<View | null>(null);
  const [pages, setPages] = useState<Readonly<Record<string, PageInfo>>>({});
  const [stage, setStage] = useState<Size>({ width: 0, height: 0 });

  const viewportAspect = stage.height > 0 ? stage.width / stage.height : 0;
  const aspect = pages[url]?.aspect ?? null;
  const long = isLongImage(aspect, viewportAspect);
  const zoomable = pages[url]?.state === 'loaded' && aspect !== null && !long;
  const zoom = view?.url === url ? view.zoom : IDENTITY;
  const zoomed = zoom.scale > 1;

  useLayoutEffect(() => {
    const el = pager.current;
    if (el === null) return;
    // Opened on the page it was asked for, without travelling there.
    el.scrollTo({ left: first * el.clientWidth, behavior: 'instant' });
    if (typeof ResizeObserver === 'undefined') return;

    let size: Size | null = null;
    const observer = new ResizeObserver(() => {
      const now = { width: el.clientWidth, height: el.clientHeight };
      if (now.width === size?.width && now.height === size.height) return;
      if (size !== null) {
        // Resized: the page shown stays the page shown, at the new width, and its picture goes back to its own size.
        el.scrollTo({
          left: Math.round(el.scrollLeft / size.width) * now.width,
          behavior: 'instant',
        });
        setView(null);
      }
      size = now;
      setStage(now);
    });
    observer.observe(el);
    return () => observer.disconnect();
  }, [first]);

  // The page behind cannot scroll while the viewer is open, and the focus starts on 닫기 and stays in.
  useEffect(() => {
    const el = panel.current;
    if (el === null) return;

    // Read before the focus moves into the viewer.
    const opener = document.activeElement as HTMLElement | null;
    const body = document.body;
    const pageScroll = body.style.overflow;
    body.style.overflow = 'hidden';
    dialogOpened(el);

    const focusCloseButton = () => closeButton.current?.focus({ preventScroll: true });
    const onFocusIn = (event: FocusEvent) => {
      // Only the frontmost dialog holds the focus: a sheet opened from the viewer owns it until it closes.
      if (event.target instanceof Node && !el.contains(event.target) && holdsFocus(el)) {
        focusCloseButton();
      }
    };

    document.addEventListener('focusin', onFocusIn);
    focusCloseButton();

    return () => {
      document.removeEventListener('focusin', onFocusIn);
      body.style.overflow = pageScroll;
      dialogClosed(el);
      // The viewer is out of the document by now, so no focus can be left in it.
      opener?.focus({ preventScroll: true });
    };
  }, [requestClose]);

  /** Pages to `at`: the CSS says how it travels, smoothly or, under reduced motion, at once. */
  const goTo = useCallback(
    (at: number) => {
      const el = pager.current;
      if (el !== null && at >= 0 && at < images.length) el.scrollTo({ left: at * el.clientWidth });
    },
    [images.length]
  );

  // The keys are the frontmost dialog's: a sheet opened from the viewer gets its own.
  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      const el = panel.current;
      if (el === null || !holdsFocus(el)) return;
      if (event.key === 'Escape') {
        requestClose();
        return;
      }
      if (event.key === 'Tab') {
        // Tab turns back at the last stop of the viewer and at its first, and brings the focus in from outside.
        const stops = Array.from(el.querySelectorAll<HTMLElement>(FOCUSABLE));
        const firstStop = stops[0];
        const lastStop = stops[stops.length - 1];
        if (firstStop === undefined) return;
        const here = document.activeElement;
        const leaving = !el.contains(here) || here === (event.shiftKey ? firstStop : lastStop);
        if (!leaving) return;
        event.preventDefault();
        (event.shiftKey ? lastStop : firstStop).focus();
        return;
      }
      if (event.altKey || event.ctrlKey || event.metaKey) return;
      const step = (direction: 1 | -1) => {
        if (!zoomable || aspect === null) return;
        // One step up or down, about the middle of the picture.
        setView({
          url,
          zoom: zoomCentre(zoom, zoomStep(zoom.scale, direction), fittedSize(aspect, stage)),
          instant: false,
        });
      };
      if (event.key === 'ArrowLeft') goTo(current - 1);
      else if (event.key === 'ArrowRight') goTo(current + 1);
      else if (event.key === '+' || event.key === '=') step(1);
      else if (event.key === '-' || event.key === '_') step(-1);
    };
    document.addEventListener('keydown', onKeyDown);
    return () => document.removeEventListener('keydown', onKeyDown);
  }, [aspect, current, goTo, requestClose, stage, url, zoom, zoomable]);

  /** The picture at 2x, about the middle of it, in a step that eases: what the zoom button goes to. */
  const twice: View | null =
    zoomable && aspect !== null
      ? { url, zoom: zoomCentre(zoom, 2, fittedSize(aspect, stage)), instant: false }
      : null;

  const onPageScroll = (event: UIEvent<HTMLDivElement>) => {
    const el = event.currentTarget;
    if (el.clientWidth === 0) return;
    const at = Math.round(el.scrollLeft / el.clientWidth);
    if (at === index) return;
    setIndex(at);
    // The zoom was the picture shown before. This one comes at its own size.
    setView(null);
  };

  const learnPage = useCallback((at: string, info: PageInfo) => {
    setPages((all) => {
      const known = all[at];
      return known?.state === info.state && known.aspect === info.aspect
        ? all
        : { ...all, [at]: info };
    });
  }, []);

  /** Ends a swipe where it stands, or where one that was let go was heading. */
  function endSwipe(g: Gesture, letGo: boolean): void {
    const swipe = g.swipe;
    g.swipe = null;
    const el = pager.current;
    if (el === null) return;
    // Until the pager is let go it is dragged by hand, and must not be snapped back to its page at every step.
    el.style.scrollSnapType = '';
    if (swipe === null) return;
    const last = swipe.path[swipe.path.length - 1];
    goTo(
      pageAfterDrag(
        swipe.page,
        last === undefined ? 0 : last[1],
        letGo ? releaseSpeed(swipe.path) : 0,
        el.clientWidth,
        images.length
      )
    );
  }

  /** Ends the gesture. What it was says what is left to do. */
  function finish(g: Gesture, tap: { time: number; point: Point } | null, letGo: boolean): void {
    if (g.timer !== null) clearTimeout(g.timer);
    g.timer = null;
    const kind = g.kind;
    g.kind = 'off';
    if (kind === 'press') {
      if (tap === null) return;
      if (g.doubleTap) {
        lastTap.current = null;
        // A double-tap puts a zoomed picture back. At 1x it does nothing.
        setView((last) => (last?.url === g.url ? null : last));
      } else {
        lastTap.current = tap;
      }
    } else if (kind === 'swipe') {
      endSwipe(g, letGo);
    } else if (kind === 'pan' || kind === 'pinch') {
      // From here a change of the zoom may ease again.
      setView((last) => (last === null || !last.instant ? last : { ...last, instant: false }));
    }
  }

  function onDown(event: PagePointerEvent, picture: Picture): void {
    // A gesture begins once no pointer is down, or on a page other than the one before was on.
    let g = gesture.current;
    if (g === null || g.pointers.size === 0 || g.slot !== event.currentTarget) {
      g = {
        slot: event.currentTarget,
        url: picture.url,
        kind: 'off',
        pointers: new Map(),
        start: { x: 0, y: 0 },
        doubleTap: false,
        timer: null,
        swipe: null,
        drag: null,
      };
      gesture.current = g;
      longPressLifted.current = false;
    }
    const pointer = pointOf(event);
    g.pointers.set(event.pointerId, pointer);
    // Wherever a pointer goes from here, this page hears of it.
    event.currentTarget.setPointerCapture(event.pointerId);

    if (g.pointers.size > 1) {
      // A second finger: no press any more, and on a picture that zooms the pinch takes over from whatever was going on.
      const was = g.kind;
      finish(g, null, false);
      if (was === 'off' || was === 'held' || picture.long || picture.aspect === null) return;
      const [a, b] = g.pointers.values();
      const box = boxOf(event, picture.aspect);
      g.kind = 'pinch';
      g.drag = {
        zoom: view?.url === g.url ? view.zoom : IDENTITY,
        from: { x: 0, y: 0 },
        pair: [inBox(a, box), inBox(b, box)],
      };
      setView({ url: g.url, zoom: g.drag.zoom, instant: true });
      return;
    }

    // The gesture is the viewer's own only where it starts on a picture: around one the browser scrolls the pager itself.
    g.start = pointer;
    g.doubleTap = false;
    if (!(event.target instanceof HTMLImageElement)) return;
    if (event.pointerType === 'mouse' && event.button !== 0) return;
    g.kind = 'press';
    g.doubleTap = isDoubleTap(event.timeStamp, pointer, lastTap.current);
    if (onMore === undefined) return;
    g.timer = setTimeout(() => {
      g.timer = null;
      if (g.kind !== 'press') return;
      g.kind = 'held';
      onMore(imageTarget(g.url));
    }, LONG_PRESS_MS);
  }

  function onMove(event: PagePointerEvent, g: Gesture, picture: Picture): void {
    if (!g.pointers.has(event.pointerId)) return;
    const pointer = pointOf(event);
    g.pointers.set(event.pointerId, pointer);

    if (g.kind === 'press') {
      if (distance(pointer, g.start) <= HOLD_SLOP) return;
      finish(g, null, false);
      if (view?.url === g.url && picture.aspect !== null) {
        // A zoomed picture is dragged, whatever way the pointer goes: the page does not move.
        g.kind = 'pan';
        g.drag = {
          zoom: view.zoom,
          from: inBox(g.start, boxOf(event, picture.aspect)),
          pair: null,
        };
        setView({ ...view, instant: true });
      } else if (picture.long) {
        // Of a long picture the browser scrolls up and down, and leaves a sideways drag to the viewer.
        if (isHorizontal(g.start, pointer)) beginSwipe(g, g.start);
      } else if (!isHorizontal(g.start, pointer)) {
        // A picture at 1x, dragged up or down: the browser leaves it alone, so a drag that turns sideways may yet page.
        g.kind = 'rescuable';
      }
      // A picture at 1x, dragged sideways from the start: the browser pages it, and takes the gesture.
      return;
    }

    if (g.kind === 'rescuable') {
      const sideways = pointer.x - g.start.x;
      if (
        Math.abs(sideways) >= RESCUE_DISTANCE &&
        Math.abs(sideways) > Math.abs(pointer.y - g.start.y)
      ) {
        beginSwipe(g, pointer);
      }
      return;
    }

    const swipe = g.swipe;
    const drag = g.drag;
    const box = picture.aspect === null ? null : boxOf(event, picture.aspect);
    if (g.kind === 'swipe' && swipe !== null) {
      const el = pager.current;
      if (el === null || el.clientWidth === 0) return;
      const left = Math.max(
        0,
        Math.min((images.length - 1) * el.clientWidth, swipe.from + swipe.pointer.x - pointer.x)
      );
      el.scrollTo({ left, behavior: 'instant' });
      swipe.path.push([event.timeStamp, left - swipe.from]);
    } else if (g.kind === 'pan' && drag !== null && box !== null) {
      const at = inBox(pointer, box);
      setZoomed(g.url, pan(drag.zoom, { x: at.x - drag.from.x, y: at.y - drag.from.y }, box));
    } else if (g.kind === 'pinch' && drag !== null && drag.pair !== null && box !== null) {
      const [a, b] = g.pointers.values();
      setZoomed(g.url, pinch(drag.zoom, drag.pair, [inBox(a, box), inBox(b, box)], box));
    }
  }

  function onUp(event: PagePointerEvent, g: Gesture, picture: Picture): void {
    if (!g.pointers.has(event.pointerId)) return;
    // The browser or the system took the gesture: it is over for every pointer.
    if (event.type === 'pointercancel') {
      g.pointers.clear();
      finish(g, null, false);
      return;
    }
    const pointer = pointOf(event);
    g.pointers.delete(event.pointerId);
    const box = picture.aspect === null ? null : boxOf(event, picture.aspect);
    if (g.kind === 'pinch' && g.pointers.size === 1) {
      // One finger is left: it goes on dragging the picture, unless the pinch left it at its own size.
      const left = [...g.pointers.values()][0];
      if (view?.url === g.url && box !== null) {
        g.kind = 'pan';
        g.drag = { zoom: view.zoom, from: inBox(left, box), pair: null };
      } else {
        g.kind = 'off';
      }
      return;
    }
    if (g.pointers.size > 0) return;
    const was = g.kind;
    finish(g, was === 'press' ? { time: event.timeStamp, point: pointer } : null, true);
    // The finger that made the long-press is lifted: see endTouch.
    if (was === 'held') longPressLifted.current = true;
  }

  /** The pager follows the pointer from now on. */
  function beginSwipe(g: Gesture, pointer: Point): void {
    const el = pager.current;
    if (el === null) return;
    g.kind = 'swipe';
    g.swipe = { page: current, from: el.scrollLeft, pointer, path: [] };
    el.style.scrollSnapType = 'none';
  }

  /** Where the picture of a page lies on the screen, not zoomed. */
  function boxOf(event: PagePointerEvent, pictureAspect: number): Box {
    const page = event.currentTarget.getBoundingClientRect();
    const size = fittedSize(pictureAspect, stage);
    return {
      x: page.left + (stage.width - size.width) / 2,
      y: page.top + (stage.height - size.height) / 2,
      ...size,
    };
  }

  /** Shows the picture at `url` zoomed. Back at its own size, it is a picture that is not zoomed. */
  function setZoomed(at: string, to: Zoom): void {
    setView(to.scale > 1 ? { url: at, zoom: to, instant: true } : null);
  }

  return createPortal(
    <div
      ref={panel}
      role="dialog"
      aria-modal="true"
      aria-label="이미지 보기"
      tabIndex={-1}
      className={FRAME}
      onClick={stay}
      onTouchCancel={stay}
      onTouchEnd={(event) => endTouch(event, longPressLifted)}
      onTouchMove={stay}
      onTouchStart={stay}
      onContextMenu={(event) => event.preventDefault()}
    >
      <div className="relative min-h-0 flex-1">
        <div ref={pager} onScroll={onPageScroll} className={PAGER}>
          <div className="flex h-full">
            {images.map((image, at) => {
              // Only the pages next to the one shown are put in: a post may have dozens of pictures.
              if (Math.abs(at - current) > 1) return <div key={at} className={PAGE} />;
              const picture: Picture = {
                url: image,
                aspect: pages[image]?.aspect ?? null,
                long: isLongImage(pages[image]?.aspect ?? null, viewportAspect),
              };
              const handlers: PageHandlers = {
                onPointerDown: (event) => onDown(event, picture),
                onPointerMove: (event) => {
                  const g = gesture.current;
                  if (g !== null) onMove(event, g, picture);
                },
                onPointerUp: (event) => {
                  const g = gesture.current;
                  if (g !== null) onUp(event, g, picture);
                },
                onPointerCancel: (event) => {
                  const g = gesture.current;
                  if (g !== null) onUp(event, g, picture);
                },
              };
              return (
                <ViewerPage
                  key={at}
                  url={image}
                  index={at}
                  viewportAspect={viewportAspect}
                  view={view}
                  handlers={handlers}
                  onLearn={learnPage}
                />
              );
            })}
          </div>
        </div>

        <div className="pointer-events-none absolute inset-0 flex flex-col justify-between p-2">
          <div className="flex items-center justify-between">
            <Button
              ref={closeButton}
              type="button"
              variant="ghost"
              size="icon"
              aria-label="닫기"
              onClick={requestClose}
              className={CHROME_BUTTON}
            >
              <X aria-hidden="true" className="size-5" />
            </Button>
            <div className="flex items-center gap-2">
              <Button
                type="button"
                variant="ghost"
                size="icon"
                aria-label={zoomed ? '원래 크기' : '확대'}
                aria-pressed={zoomed}
                disabled={!zoomable}
                onClick={() => setView(zoomed ? null : twice)}
                className={CHROME_BUTTON}
              >
                {zoomed ? (
                  <ZoomOut aria-hidden="true" className="size-5" />
                ) : (
                  <ZoomIn aria-hidden="true" className="size-5" />
                )}
              </Button>
              {onMore !== undefined && (
                <Button
                  type="button"
                  variant="ghost"
                  size="icon"
                  aria-label="더보기"
                  aria-haspopup="dialog"
                  onClick={() => onMore(imageTarget(url))}
                  className={CHROME_BUTTON}
                >
                  <MoreHorizontal aria-hidden="true" className="size-5" />
                </Button>
              )}
            </div>
          </div>
          {images.length > 1 && (
            <div className="flex items-center justify-between">
              <Button
                type="button"
                variant="ghost"
                size="icon"
                aria-label="이전"
                disabled={current === 0}
                onClick={() => goTo(current - 1)}
                className={CHROME_BUTTON}
              >
                <ChevronLeft aria-hidden="true" className="size-5" />
              </Button>
              <span
                role="status"
                aria-label={`이미지 ${current + 1} / ${images.length}`}
                className={CHROME_POSITION}
              >
                {current + 1} / {images.length}
              </span>
              <Button
                type="button"
                variant="ghost"
                size="icon"
                aria-label="다음"
                disabled={current === images.length - 1}
                onClick={() => goTo(current + 1)}
                className={CHROME_BUTTON}
              >
                <ChevronRight aria-hidden="true" className="size-5" />
              </Button>
            </div>
          )}
        </div>
      </div>
    </div>,
    document.body
  );
}

interface ViewerPageProps {
  url: string;
  /** Its place in the viewer, from 0: the picture is named by it. */
  index: number;
  /** The width over height of the viewer: a picture narrower than that is long. */
  viewportAspect: number;
  /** How it is zoomed now, when it is the picture that is. */
  view: View | null;
  handlers: PageHandlers;
  /** Tells the viewer what the page found about its picture. */
  onLearn: (url: string, info: PageInfo) => void;
}

/**
 * One picture of the pager: a placeholder until it has loaded, a way to try
 * again when it failed, and then the picture itself, long or one to zoom.
 */
function ViewerPage({ url, index, viewportAspect, view, handlers, onLearn }: ViewerPageProps) {
  const [state, retry] = useImageLoader(url);
  // What the picture said of itself as the element showing it loaded. Only what was found for this address counts.
  const [measured, setMeasured] = useState<{ url: string; width: number; height: number } | null>(
    null
  );
  const [brokenAt, setBrokenAt] = useState<string | null>(null);

  const failed = state === 'failed' || brokenAt === url;
  // The size is read from the element that shows the picture, so that it never appears in a layout not its own.
  const shown = state === 'loaded' && measured?.url === url && !failed;
  const aspect = shown && measured !== null ? measured.width / measured.height : null;
  const long = isLongImage(aspect, viewportAspect);
  const loadState: LoadState = failed ? 'failed' : shown ? 'loaded' : 'loading';

  useEffect(() => {
    onLearn(url, { state: loadState, aspect });
  }, [aspect, loadState, onLearn, url]);

  const onLoad = (event: SyntheticEvent<HTMLImageElement>) => {
    const { naturalWidth: width, naturalHeight: height } = event.currentTarget;
    if (width === 0 || height === 0) setBrokenAt(url);
    else setMeasured({ url, width, height });
  };
  const tryAgain = () => {
    setBrokenAt(null);
    retry();
  };

  const own = view?.url === url ? view : null;
  const zoom = own?.zoom ?? IDENTITY;
  const alt = `${index + 1}번째 이미지`;
  let body: ReactNode;
  if (failed) {
    body = (
      <div
        role="alert"
        className="absolute inset-0 flex flex-col items-center justify-center gap-2 bg-muted px-4 text-center text-muted-foreground"
      >
        <ImageOff aria-hidden="true" className="size-8" />
        <p className="text-sm">이미지를 불러오지 못했습니다</p>
        <Button type="button" variant="outline" className="h-11" onClick={tryAgain}>
          다시 시도
        </Button>
      </div>
    );
  } else if (!shown) {
    body = (
      <>
        <Skeleton aria-hidden="true" className="absolute inset-0 rounded-none" />
        {/* Loaded off the page, and now once more by the element that shows it: that is where its size is read. */}
        {state === 'loaded' && (
          <img
            src={url}
            alt=""
            aria-hidden="true"
            referrerPolicy="no-referrer"
            decoding="async"
            className="invisible"
            onLoad={onLoad}
            onError={() => setBrokenAt(url)}
          />
        )}
      </>
    );
  } else if (long) {
    body = (
      <div className={LONG_PICTURE}>
        <img
          src={url}
          alt={alt}
          referrerPolicy="no-referrer"
          decoding="async"
          draggable={false}
          className="block w-full touch-pan-y"
        />
        <div aria-hidden="true" className={LONG_PICTURE_END} />
      </div>
    );
  } else {
    body = (
      <img
        src={url}
        alt={alt}
        referrerPolicy="no-referrer"
        decoding="async"
        draggable={false}
        // At 1x the browser pages a sideways drag itself. Zoomed in, every drag pans the picture instead.
        className={cn(
          PICTURE,
          own?.instant && 'transition-none',
          zoom.scale > 1 ? 'touch-none' : 'touch-pan-x'
        )}
        style={zoom.scale > 1 ? { transform: toTransform(zoom) } : undefined}
      />
    );
  }

  return (
    <div {...handlers} className={PAGE}>
      {body}
    </div>
  );
}
