import {
  useCallback,
  useEffect,
  useRef,
  type MouseEvent as ReactMouseEvent,
  type PointerEvent as ReactPointerEvent,
  type RefObject,
} from 'react';

/** A press held this long, in ms, is a long press. */
const LONG_PRESS_MS = 500;
/** How far the pointer may travel while it is held, in px: beyond it is a drag. */
const LONG_PRESS_SLOP = 10;
/** A long press does not start on these: a thumb held still before a drag is not a press on the media. */
const NO_LONG_PRESS = 'input, [role="slider"]';

/** A pointer that went down on the media and may still become a long press. */
interface Hold {
  pointerId: number;
  x: number;
  y: number;
  timer: ReturnType<typeof setTimeout>;
}

/** Ends the press being watched, before it counts as long. */
function endHold(hold: RefObject<Hold | null>): void {
  if (hold.current === null) return;
  clearTimeout(hold.current.timer);
  hold.current = null;
}

/** For the element a long press is watched on. All of it goes on that element: `<div {...press}>`. */
export interface LongPressHandlers<E extends HTMLElement> {
  /** Binds the native touch listeners of the element. Its cleanup forgets a press still watched. */
  ref: (element: E | null) => void | (() => void);
  onPointerDown: (event: ReactPointerEvent<E>) => void;
  onPointerMove: (event: ReactPointerEvent<E>) => void;
  onPointerUp: (event: ReactPointerEvent<E>) => void;
  onPointerCancel: (event: ReactPointerEvent<E>) => void;
  onClickCapture: (event: ReactMouseEvent<E>) => void;
}

/**
 * A long press on an element: the first finger, or the main mouse button,
 * held still for half a second runs `onLongPress`, once. Let go, moved beyond
 * a few pixels, or taken by the browser first, it is a tap or a drag, and
 * nothing runs. Left out, nothing is watched and no touch is kept from the
 * browser.
 *
 * The finger that made a long press neither scrolls nor clicks: Chromium
 * clicks where it lifts, which is the scrim of the sheet the press opened,
 * and that click would close the sheet at once. React's own touch listeners
 * are passive: only the native ones of `ref` can keep a touch.
 *
 * The WebView's own answer to a long press is not the hook's to keep: the
 * container of the element takes `select-none`, `[-webkit-touch-callout:none]`
 * and keeps its `contextmenu`.
 */
export function useLongPress<E extends HTMLElement>(
  onLongPress: (() => void) | undefined
): LongPressHandlers<E> {
  const hold = useRef<Hold | null>(null);
  /** The pointer whose long press fired: letting it go is not also a tap. */
  const heldPointer = useRef<number | null>(null);
  // A press outlives the render it began in: it runs the callback of the latest.
  const latest = useRef(onLongPress);
  useEffect(() => {
    latest.current = onLongPress;
  });

  // The same function every render: a render must not detach it, which would end a press in progress.
  const watch = useCallback((element: E | null) => {
    if (element === null) return;
    const onTouch = (event: TouchEvent) => {
      if (heldPointer.current !== null) event.preventDefault();
    };
    element.addEventListener('touchmove', onTouch, { passive: false });
    element.addEventListener('touchend', onTouch, { passive: false });
    return () => {
      element.removeEventListener('touchmove', onTouch);
      element.removeEventListener('touchend', onTouch);
      endHold(hold);
    };
  }, []);

  const onPointerDown = (event: ReactPointerEvent<E>) => {
    if (!event.isPrimary || event.button !== 0) return;
    // A new press: nothing is held over from the one before.
    endHold(hold);
    heldPointer.current = null;
    if (onLongPress === undefined || (event.target as Element).closest(NO_LONG_PRESS) !== null) {
      return;
    }
    const pointerId = event.pointerId;
    hold.current = {
      pointerId,
      x: event.clientX,
      y: event.clientY,
      timer: setTimeout(() => {
        hold.current = null;
        heldPointer.current = pointerId;
        latest.current?.();
      }, LONG_PRESS_MS),
    };
  };

  const onPointerMove = (event: ReactPointerEvent<E>) => {
    const pressing = hold.current;
    if (pressing === null || pressing.pointerId !== event.pointerId) return;
    if (Math.hypot(event.clientX - pressing.x, event.clientY - pressing.y) <= LONG_PRESS_SLOP) {
      return;
    }
    endHold(hold);
  };

  const onPointerEnd = (event: ReactPointerEvent<E>) => {
    if (hold.current?.pointerId === event.pointerId) endHold(hold);
  };

  const onClickCapture = (event: ReactMouseEvent<E>) => {
    const pressed = heldPointer.current;
    if (pressed === null) return;
    // Another pointer, or the keyboard, which has none: not how this press ended.
    if ((event.nativeEvent as PointerEvent).pointerId !== pressed) return;
    // The sheet is open: nothing under the pointer may run on its being let go.
    heldPointer.current = null;
    event.preventDefault();
    event.stopPropagation();
  };

  return {
    ref: watch,
    onPointerDown,
    onPointerMove,
    onPointerUp: onPointerEnd,
    onPointerCancel: onPointerEnd,
    onClickCapture,
  };
}
