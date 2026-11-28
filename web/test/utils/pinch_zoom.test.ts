import { describe, expect, it } from 'vitest';
import {
  DOUBLE_TAP_MS,
  IDENTITY,
  MAX_SCALE,
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
  zoomAbout,
  zoomCentre,
  zoomStep,
  type Point,
  type Zoom,
} from '../../src/utils/pinch_zoom';

/** A picture 400 wide and 200 high on the screen. */
const box = { width: 400, height: 200 };
/** The viewer it is shown in, and its width over height. */
const viewer = { width: 400, height: 800 };
const viewerAspect = 0.5;

describe('telling a long picture', () => {
  it('is long when, at the width of the viewer, it would be taller than the viewer', () => {
    expect(isLongImage(1200 / 800, viewerAspect)).toBe(false);
    expect(isLongImage(800 / 1200, viewerAspect)).toBe(false);
    // As tall as the viewer at its width: it fits exactly.
    expect(isLongImage(400 / 800, viewerAspect)).toBe(false);
    expect(isLongImage(400 / 1600, viewerAspect)).toBe(true);
    expect(isLongImage(1 / 3, viewerAspect)).toBe(true);
  });

  it('is not long while nothing is known of it, or of the viewer', () => {
    expect(isLongImage(null, viewerAspect)).toBe(false);
    expect(isLongImage(0.25, 0)).toBe(false);
    expect(isLongImage(0.25, Number.NaN)).toBe(false);
  });

  it('fits a picture as large as the viewer holds, keeping its shape', () => {
    expect(fittedSize(2, viewer)).toEqual(box);
    expect(fittedSize(1.5, viewer).width).toBe(400);
    expect(fittedSize(1.5, viewer).height).toBeCloseTo(400 / 1.5, 5);
    // Taller than wide, but not long: it still fits by its width.
    expect(fittedSize(0.75, viewer).width).toBe(400);
    expect(fittedSize(0.75, viewer).height).toBeCloseTo(400 / 0.75, 5);
    // Narrower than the viewer is tall: it fits by its height.
    expect(fittedSize(0.25, viewer)).toEqual({ width: 200, height: 800 });
  });
});

describe('zooming a picture', () => {
  it('is its own box at 1x', () => {
    expect(IDENTITY).toEqual({ scale: 1, x: 0, y: 0 });
    expect(toTransform(IDENTITY)).toBe('translate(0px, 0px) scale(1)');
  });

  it('zoomed about the middle keeps the middle where it is', () => {
    expect(zoomCentre(IDENTITY, 2, box)).toEqual({ scale: 2, x: -200, y: -100 });
  });

  it('zoomed about a point keeps that point where it is', () => {
    expect(zoomAbout(IDENTITY, 2, { x: 100, y: 50 }, box)).toEqual({ scale: 2, x: -100, y: -50 });
    // The top left corner stays in the top left corner.
    expect(zoomAbout(IDENTITY, 2, { x: 0, y: 0 }, box)).toEqual({ scale: 2, x: 0, y: 0 });
  });

  it('never goes below 1x or above 4x', () => {
    expect(zoomCentre(IDENTITY, 0.5, box)).toEqual(IDENTITY);
    expect(zoomCentre(IDENTITY, 2 * MAX_SCALE, box).scale).toBe(MAX_SCALE);
  });

  it('never shows what lies beyond the picture', () => {
    // Four times the size about the middle: each edge moves out by a box and a half.
    const four = zoomCentre(IDENTITY, 4, box);
    expect(four).toEqual({ scale: 4, x: -600, y: -300 });
    // The far corner of the picture is at the far corner of its box, or past it.
    expect(box.width * 4 + four.x).toBeGreaterThan(box.width);
    expect(box.height * 4 + four.y).toBeGreaterThan(box.height);
    // Dragged past its edge, the picture stops where its edge meets the edge of its box.
    expect(pan(four, { x: 5000, y: -5000 }, box)).toEqual({ scale: 4, x: 0, y: -600 });
    expect(pan(four, { x: -5000, y: 5000 }, box)).toEqual({ scale: 4, x: -1200, y: 0 });
  });

  it('pans only once zoomed', () => {
    expect(pan(IDENTITY, { x: 100, y: 50 }, box)).toEqual(IDENTITY);
    expect(pan(zoomCentre(IDENTITY, 2, box), { x: 50, y: -30 }, box)).toEqual({
      scale: 2,
      x: -150,
      y: -130,
    });
  });

  it('a pinch zooms by how far the fingers spread, about the middle of them', () => {
    const from: [Point, Point] = [
      { x: 100, y: 100 },
      { x: 200, y: 100 },
    ];
    // Twice the spread: twice the size, with the point between the fingers staying put.
    expect(
      pinch(
        IDENTITY,
        from,
        [
          { x: 50, y: 100 },
          { x: 250, y: 100 },
        ],
        box
      )
    ).toEqual({ scale: 2, x: -150, y: -100 });
    // Less spread than before is still no smaller than the box.
    expect(
      pinch(
        IDENTITY,
        from,
        [
          { x: 125, y: 100 },
          { x: 175, y: 100 },
        ],
        box
      )
    ).toEqual(IDENTITY);
    // Never past 4x.
    const wide = pinch(
      IDENTITY,
      from,
      [
        { x: 0, y: 100 },
        { x: 400, y: 100 },
      ],
      box
    );
    expect(wide.scale).toBe(MAX_SCALE);
    // It goes on from where it is: spread again from 4x, it stays at 4x.
    expect(
      pinch(
        wide,
        [
          { x: 0, y: 100 },
          { x: 400, y: 100 },
        ],
        [
          { x: -200, y: 100 },
          { x: 600, y: 100 },
        ],
        box
      )
    ).toEqual(wide);
  });

  it('a pinch whose middle moves carries the picture along', () => {
    const twice = zoomCentre(IDENTITY, 2, box);
    expect(
      pinch(
        twice,
        [
          { x: 100, y: 100 },
          { x: 200, y: 100 },
        ],
        [
          { x: 110, y: 120 },
          { x: 210, y: 120 },
        ],
        box
      )
    ).toEqual({ scale: 2, x: -190, y: -80 });
  });

  it('a pinch from two fingers on the same spot changes nothing', () => {
    const spot: Point = { x: 100, y: 100 };
    expect(pinch(IDENTITY, [spot, spot], [spot, { x: 150, y: 100 }], box)).toEqual(IDENTITY);
  });

  it('keeps its numbers whole however it is zoomed and panned', () => {
    let zoom: Zoom = IDENTITY;
    for (const scale of [1.3, 2.7, 3.9, 1.05]) {
      zoom = zoomCentre(zoom, scale, box);
      zoom = pan(zoom, { x: 37, y: -23 }, box);
      expect(
        Number.isFinite(zoom.x) && Number.isFinite(zoom.y) && Number.isFinite(zoom.scale)
      ).toBe(true);
      expect(zoom.scale).toBeGreaterThanOrEqual(1);
      expect(zoom.scale).toBeLessThanOrEqual(MAX_SCALE);
    }
  });

  it('goes up and down in steps: 1, 2, 3, 4, and back', () => {
    expect(zoomStep(1, 1)).toBe(2);
    expect(zoomStep(2, 1)).toBe(3);
    expect(zoomStep(3, 1)).toBe(4);
    expect(zoomStep(4, 1)).toBe(4);
    expect(zoomStep(2, -1)).toBe(1);
    expect(zoomStep(1, -1)).toBe(1);
    // From between two steps, a step goes to the next one up, or to the one below.
    expect(zoomStep(2.5, 1)).toBe(3);
    expect(zoomStep(2.5, -1)).toBe(2);
    expect(zoomStep(3.2, 1)).toBe(4);
    expect(zoomStep(3.2, -1)).toBe(3);
  });
});

describe('paging', () => {
  // Pages 400 wide, five of them.
  const width = 400;

  it('lets go of the drag where it is when it went less than half a page', () => {
    expect(pageAfterDrag(2, 0, 0, width, 5)).toBe(2);
    expect(pageAfterDrag(2, 100, 0, width, 5)).toBe(2);
    expect(pageAfterDrag(2, -199, 0, width, 5)).toBe(2);
  });

  it('goes on to the next page, or back to the one before, past half a page', () => {
    expect(pageAfterDrag(2, 201, 0, width, 5)).toBe(3);
    expect(pageAfterDrag(2, -201, 0, width, 5)).toBe(1);
    expect(pageAfterDrag(2, 400, 0, width, 5)).toBe(3);
  });

  it('a flick pages on even when it is shorter than half a page', () => {
    expect(pageAfterDrag(2, 30, 0.5, width, 5)).toBe(3);
    expect(pageAfterDrag(2, -30, -0.5, width, 5)).toBe(1);
    // The way it was going when let go is the way it pages.
    expect(pageAfterDrag(2, 30, -0.5, width, 5)).toBe(1);
    // A slow short drag is no flick, and neither is a fast one that hardly moved.
    expect(pageAfterDrag(2, 30, 0.1, width, 5)).toBe(2);
    expect(pageAfterDrag(2, 10, 5, width, 5)).toBe(2);
  });

  it('never leaves the first or the last page', () => {
    expect(pageAfterDrag(0, -100, -5, width, 5)).toBe(0);
    expect(pageAfterDrag(4, 100, 5, width, 5)).toBe(4);
  });

  it('reads the speed of a drag from its last moments', () => {
    expect(releaseSpeed([])).toBe(0);
    expect(releaseSpeed([[10, 0]])).toBe(0);
    expect(
      releaseSpeed([
        [10, 0],
        [10, 0],
      ])
    ).toBe(0);
    expect(
      releaseSpeed([
        [0, 0],
        [16, 10],
        [32, 20],
        [48, 30],
      ])
    ).toBe(0.625);
    // What went on before the last 100ms is not looked at: from 200 on it moved 20 in 32.
    expect(
      releaseSpeed([
        [0, 100],
        [200, 0],
        [216, 10],
        [232, 20],
      ])
    ).toBe(0.625);
    // Stopped before it was let go: no speed.
    expect(
      releaseSpeed([
        [0, 0],
        [200, 0],
        [216, 10],
        [232, 20],
        [280, 20],
        [320, 20],
      ])
    ).toBe(0);
  });
});

describe('taps and drags', () => {
  it('measures a drag', () => {
    expect(distance({ x: 0, y: 0 }, { x: 3, y: 4 })).toBe(5);
    expect(isHorizontal({ x: 0, y: 0 }, { x: -30, y: 10 })).toBe(true);
    expect(isHorizontal({ x: 0, y: 0 }, { x: 10, y: 30 })).toBe(false);
    // More up or down than sideways: not a sideways drag.
    expect(isHorizontal({ x: 0, y: 0 }, { x: 10, y: 10 })).toBe(false);
  });

  it('tells a double-tap: a tap soon after the last one, and near it', () => {
    const first = { time: 1000, point: { x: 100, y: 200 } };
    expect(isDoubleTap(1000 + DOUBLE_TAP_MS, { x: 120, y: 210 }, first)).toBe(true);
    expect(isDoubleTap(1001 + DOUBLE_TAP_MS, { x: 120, y: 210 }, first)).toBe(false);
    expect(isDoubleTap(1100, { x: 140, y: 200 }, first)).toBe(false);
    expect(isDoubleTap(1100, { x: 120, y: 210 }, null)).toBe(false);
  });
});
