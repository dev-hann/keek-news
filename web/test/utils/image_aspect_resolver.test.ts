// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { resolveImageAspect } from '../../src/utils/image_aspect_resolver';

/** The image loads of the test: nothing loads unless the test says it did. */
const loads: FakeImage[] = [];

class FakeImage {
  onload: (() => void) | null = null;
  onerror: (() => void) | null = null;
  referrerPolicy = '';
  naturalWidth = 0;
  naturalHeight = 0;
  readonly src: string;

  constructor(src: string) {
    this.src = src;
    loads.push(this);
  }
}

beforeEach(() => {
  loads.length = 0;
  vi.stubGlobal('Image', FakeImage);
});

afterEach(() => vi.unstubAllGlobals());

describe('resolveImageAspect', () => {
  it('answers width over height once the image has loaded', async () => {
    const aspect = resolveImageAspect('https://e.com/a.jpg');
    const image = loads[0];
    image.naturalWidth = 1200;
    image.naturalHeight = 800;
    image.onload?.();

    await expect(aspect).resolves.toBe(1.5);
    expect(image.referrerPolicy).toBe('no-referrer');
    expect(image.src).toBe('https://e.com/a.jpg');
  });

  it('fails when the image does not load', async () => {
    const aspect = resolveImageAspect('https://e.com/a.jpg');
    loads[0].onerror?.();

    await expect(aspect).rejects.toThrow('did not load');
  });

  it('fails when the image has no height', async () => {
    const aspect = resolveImageAspect('https://e.com/a.jpg');
    loads[0].onload?.();

    await expect(aspect).rejects.toThrow('no height');
  });
});
