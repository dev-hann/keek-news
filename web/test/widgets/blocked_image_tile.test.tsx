// @vitest-environment jsdom
import { act, fireEvent, render, screen, within } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { BlockedImage } from '../../src/model/blocked_image';
import { BlockedImageTile } from '../../src/widgets/blocked_image_tile';

const ADDRESS = 'https://example.com/uploads/blocked.jpg';

const image = (extra: Partial<BlockedImage> = {}): BlockedImage => ({
  url: ADDRESS,
  blockedAt: new Date(2026, 10, 28, 9),
  ...extra,
});

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

/** The 72px box the picture is shown in. */
function thumbnail(container: HTMLElement): HTMLElement {
  return container.querySelector('.size-18') as HTMLElement;
}

describe('BlockedImageTile', () => {
  beforeEach(() => {
    loads.length = 0;
    vi.stubGlobal('Image', FakeImage);
    vi.setSystemTime(new Date(2026, 10, 28, 12));
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.useRealTimers();
  });

  it('says when the image was blocked and where it is, the address on one line', () => {
    const { container } = render(<BlockedImageTile image={image()} onUnblock={() => undefined} />);
    const [when, address] = container.querySelectorAll('p');

    expect(when.textContent).toBe('3시간 전');
    expect(address.textContent).toBe(ADDRESS);
    expect(address.className).toContain('truncate');
    expect(when.className).toBe('text-sm text-muted-foreground');
    expect(address.className).toBe('truncate text-sm text-muted-foreground');
  });

  it('asks for the picture the way the images of the app load, and shows an empty box until it comes', () => {
    const { container } = render(<BlockedImageTile image={image()} onUnblock={() => undefined} />);

    expect(loads).toHaveLength(1);
    expect(loads[0]).toMatchObject({ src: ADDRESS, referrerPolicy: 'no-referrer' });
    expect(thumbnail(container).className).toContain('bg-muted');
    expect(thumbnail(container).className).toContain('rounded-lg');
    expect(container.querySelector('img')).toBeNull();
  });

  it('shows the picture once it has loaded, with no name of its own', async () => {
    const { container } = render(<BlockedImageTile image={image()} onUnblock={() => undefined} />);

    await act(() => loads[0].onload?.());

    const picture = container.querySelector('img');
    expect(picture).toHaveProperty('src', ADDRESS);
    // jsdom knows these only as attributes.
    expect(picture?.getAttribute('alt')).toBe('');
    expect(picture?.getAttribute('loading')).toBe('lazy');
    expect(picture?.getAttribute('decoding')).toBe('async');
    expect(picture?.getAttribute('referrerpolicy')).toBe('no-referrer');
    // The address next to it says what the picture is: the picture itself is not announced.
    expect(screen.queryByRole('img')).toBeNull();
  });

  it('shows a placeholder, never a broken picture, when it failed, and can still be unblocked', async () => {
    const onUnblock = vi.fn();
    const { container } = render(<BlockedImageTile image={image()} onUnblock={onUnblock} />);

    await act(() => loads[0].onerror?.());

    expect(container.querySelector('img')).toBeNull();
    const placeholder = thumbnail(container).querySelector('svg');
    expect(placeholder?.getAttribute('class')).toContain('lucide-image-off');
    expect(placeholder?.getAttribute('aria-hidden')).toBe('true');
    // No way to try again, so it is asked for once.
    expect(screen.queryByRole('button', { name: '다시 시도' })).toBeNull();
    expect(loads).toHaveLength(1);

    fireEvent.click(screen.getByRole('button', { name: '차단 해제' }));
    expect(onUnblock).toHaveBeenCalledTimes(1);
  });

  it('is a plain box, with nothing to focus, when there is no way to open the preview', () => {
    const { container } = render(<BlockedImageTile image={image()} onUnblock={() => undefined} />);

    expect(thumbnail(container).tagName).toBe('SPAN');
    expect(thumbnail(container).hasAttribute('tabindex')).toBe(false);
    expect(screen.queryByRole('button', { name: '전체화면으로 보기' })).toBeNull();
    // What acts in the row: unblocking, and that alone.
    expect(within(container).getAllByRole('button')).toEqual([
      screen.getByRole('button', { name: '차단 해제' }),
    ]);
  });

  it('opens the preview from the thumbnail when there is a way', () => {
    const onOpenPreview = vi.fn();
    const { container } = render(
      <BlockedImageTile image={image()} onUnblock={() => undefined} onOpenPreview={onOpenPreview} />
    );
    const button = screen.getByRole('button', { name: '전체화면으로 보기' });

    expect(button).toBe(thumbnail(container));
    // The picture gets the whole 72px: no padding, no border, the rounded corners clip it.
    expect(button.className).toContain('size-18');
    expect(button.className).not.toMatch(/\bsize-8\b|\bpx-|\bpy-|\bp-|\bborder\b(?!-)/);
    expect(button.className).toContain('overflow-hidden');
    expect(button.className).toContain('rounded-lg');
    fireEvent.click(button);
    expect(onOpenPreview).toHaveBeenCalledTimes(1);
  });

  it('unblocks from a 44px button that does not look destructive', () => {
    const onUnblock = vi.fn();
    render(<BlockedImageTile image={image()} onUnblock={onUnblock} />);
    const button = screen.getByRole('button', { name: '차단 해제' });

    expect(button.className).toContain('size-11');
    expect(button.className).not.toContain('text-destructive');
    expect(button.getAttribute('aria-pressed')).toBeNull();
    const icon = button.querySelector('svg');
    expect(icon?.getAttribute('class')).toContain('lucide-rotate-ccw');
    expect(icon?.getAttribute('aria-hidden')).toBe('true');

    fireEvent.click(button);
    expect(onUnblock).toHaveBeenCalledTimes(1);
  });
});
