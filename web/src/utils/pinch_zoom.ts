/**
 * The arithmetic of touching a picture: zooming by a pinch or a step, panning
 * it, telling a long picture from one to zoom, and where a dragged pager comes
 * to rest. Points and sizes are in CSS pixels.
 */

export interface Point {
  x: number;
  y: number;
}

export interface Size {
  width: number;
  height: number;
}

/** A box on the screen: where its top left corner is, and how big it is. */
export interface Box extends Point, Size {}

/**
 * A picture shown `scale` times the size of its own box and moved by `x`, `y`
 * from where that box is. At scale 1 it lies exactly in its box.
 */
export interface Zoom {
  scale: number;
  x: number;
  y: number;
}

export const IDENTITY: Zoom = { scale: 1, x: 0, y: 0 };

export const MAX_SCALE = 4;

/** How far a pointer may travel and still count as held still: a long-press, a tap. */
export const HOLD_SLOP = 10;

/** A tap is the second of a double-tap when it lands within this many pixels of the one before... */
export const DOUBLE_TAP_SLOP = 32;

/** ... and this many milliseconds after it. */
export const DOUBLE_TAP_MS = 300;

/** A drag this long, in pixels, that is released at this speed, in pixels per millisecond, pages on: a flick. */
export const FLING_DISTANCE = 24;
export const FLING_SPEED = 0.3;

/** The speed of a drag is read over this many milliseconds before it is let go. */
const SPEED_WINDOW = 100;

export function distance(a: Point, b: Point): number {
  return Math.hypot(a.x - b.x, a.y - b.y);
}

/** Which way a drag went: more sideways than up or down. */
export function isHorizontal(from: Point, to: Point): boolean {
  return Math.abs(to.x - from.x) > Math.abs(to.y - from.y);
}

/**
 * A picture so much taller than wide that, shown at the width of the viewer,
 * it would be taller than the viewer: a strip to read by scrolling, not one to
 * zoom. Aspects are width over height.
 */
export function isLongImage(aspect: number | null, viewportAspect: number): boolean {
  if (aspect === null || !(viewportAspect > 0)) return false;
  return aspect < viewportAspect;
}

/** The size of a picture with this aspect shown as large as fits in `bounds`. */
export function fittedSize(aspect: number, bounds: Size): Size {
  const width = Math.min(bounds.width, bounds.height * aspect);
  return { width, height: width / aspect };
}

/** Nothing beyond the picture is ever shown: zoomed in, it still covers its whole box. */
function withinBox(zoom: Zoom, box: Size): Zoom {
  const scale = Math.min(MAX_SCALE, Math.max(1, zoom.scale));
  return {
    scale,
    x: Math.min(0, Math.max(box.width * (1 - scale), zoom.x)),
    y: Math.min(0, Math.max(box.height * (1 - scale), zoom.y)),
  };
}

/** The picture at `scale`, with the part under `about` staying right there. `about` is from the box's corner. */
export function zoomAbout(zoom: Zoom, scale: number, about: Point, box: Size): Zoom {
  // Clamped first: at the limit of the zoom, the part under `about` stays put instead of sliding on.
  const to = Math.min(MAX_SCALE, Math.max(1, scale));
  return withinBox(
    {
      scale: to,
      x: about.x - ((about.x - zoom.x) / zoom.scale) * to,
      y: about.y - ((about.y - zoom.y) / zoom.scale) * to,
    },
    box
  );
}

/** The picture at `scale`, keeping what lies in the middle of its box right there. */
export function zoomCentre(zoom: Zoom, scale: number, box: Size): Zoom {
  return zoomAbout(zoom, scale, { x: box.width / 2, y: box.height / 2 }, box);
}

/** The picture moved by `by`, as a pointer dragging it would. */
export function pan(zoom: Zoom, by: Point, box: Size): Zoom {
  return withinBox({ ...zoom, x: zoom.x + by.x, y: zoom.y + by.y }, box);
}

/**
 * Two pointers went from `from` to `to` (the same pointer first both times):
 * the picture zooms by as much as they spread, and the part under their middle follows it.
 */
export function pinch(zoom: Zoom, from: [Point, Point], to: [Point, Point], box: Size): Zoom {
  const spread = distance(...from);
  const scale = zoom.scale * (spread > 0 ? distance(...to) / spread : 1);
  const middleOf = ([a, b]: [Point, Point]): Point => ({ x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 });
  const was = middleOf(from);
  const now = middleOf(to);
  return pan(zoomAbout(zoom, scale, was, box), { x: now.x - was.x, y: now.y - was.y }, box);
}

/** One press of the zoom button or key: 1, 2, 3, 4 and back down. From 2.5 a step goes to 3, or to 2. */
export function zoomStep(scale: number, direction: 1 | -1): number {
  const next = direction > 0 ? Math.floor(scale) + 1 : Math.ceil(scale) - 1;
  return Math.min(MAX_SCALE, Math.max(1, next));
}

export function toTransform(zoom: Zoom): string {
  return `translate(${zoom.x}px, ${zoom.y}px) scale(${zoom.scale})`;
}

/**
 * Where the pager comes to rest after a drag. `offset` is how far the drag
 * took it past page `page`, towards the next page when positive; `speed` is
 * how fast it was going when let go.
 */
export function pageAfterDrag(
  page: number,
  offset: number,
  speed: number,
  width: number,
  count: number
): number {
  const flicked = Math.abs(offset) >= FLING_DISTANCE && Math.abs(speed) >= FLING_SPEED;
  const next = offset > width / 2 || (flicked && speed > 0);
  const back = offset < -width / 2 || (flicked && speed < 0);
  return Math.min(count - 1, Math.max(0, page + (next ? 1 : 0) - (back ? 1 : 0)));
}

/**
 * How fast a drag was going when let go, in pixels per millisecond, from where
 * it was along the way: `[time, position]`, the earliest first. Zero when it
 * was not going anywhere, or barely moved.
 */
export function releaseSpeed(samples: ReadonlyArray<readonly [number, number]>): number {
  const last = samples[samples.length - 1];
  if (last === undefined) return 0;
  const first = samples.find(([time]) => last[0] - time <= SPEED_WINDOW) ?? samples[0];
  return last[0] > first[0] ? (last[1] - first[1]) / (last[0] - first[0]) : 0;
}

/** Whether a tap at `time` and `point` comes soon after the last one, and near it. */
export function isDoubleTap(
  time: number,
  point: Point,
  last: { time: number; point: Point } | null
): boolean {
  return (
    last !== null &&
    time - last.time <= DOUBLE_TAP_MS &&
    distance(point, last.point) <= DOUBLE_TAP_SLOP
  );
}
