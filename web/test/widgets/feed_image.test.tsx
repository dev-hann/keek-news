// @vitest-environment jsdom
import { act, fireEvent, render, screen } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { FeedImage } from '../../src/widgets/feed_image';

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

beforeEach(() => {
  loads.length = 0;
  vi.stubGlobal('Image', FakeImage);
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('FeedImage', () => {
  it('holds a box the shape of a picture until the picture has loaded', async () => {
    render(<FeedImage src="https://e.com/a.jpg" alt="1번째 이미지" />);
    expect(loads).toHaveLength(1);
    expect(loads[0]).toMatchObject({ src: 'https://e.com/a.jpg', referrerPolicy: 'no-referrer' });
    expect(screen.queryByRole('img')).toBeNull();

    await act(() => loads[0].onload?.());

    const image = screen.getByRole('img', { name: '1번째 이미지' });
    expect(image).toHaveProperty('src', 'https://e.com/a.jpg');
    expect(image.getAttribute('referrerpolicy')).toBe('no-referrer');
  });

  it('offers a way to try again when the picture failed, and asks once more for it', async () => {
    render(<FeedImage src="https://e.com/a.jpg" alt="1번째 이미지" />);
    await act(() => loads[0].onerror?.());

    expect(screen.getByRole('button', { name: '다시 시도' })).toBeTruthy();
    expect(loads).toHaveLength(1);

    fireEvent.click(screen.getByRole('button', { name: '다시 시도' }));
    expect(loads).toHaveLength(2);

    await act(() => loads[1].onload?.());
    expect(screen.getByRole('img', { name: '1번째 이미지' })).toBeTruthy();
  });

  it('asks for the new picture when the address changes', async () => {
    const { rerender } = render(<FeedImage src="https://e.com/a.jpg" alt="이미지" />);
    await act(() => loads[0].onload?.());
    expect(screen.getByRole('img', { name: '이미지' })).toBeTruthy();

    rerender(<FeedImage src="https://e.com/b.jpg" alt="이미지" />);
    expect(screen.queryByRole('img')).toBeNull();
    expect(loads).toHaveLength(2);

    await act(() => loads[1].onload?.());
    expect(screen.getByRole('img', { name: '이미지' })).toHaveProperty(
      'src',
      'https://e.com/b.jpg'
    );
  });

  it('ignores an answer that comes for a picture it no longer shows', async () => {
    const { rerender } = render(<FeedImage src="https://e.com/a.jpg" alt="이미지" />);
    rerender(<FeedImage src="https://e.com/b.jpg" alt="이미지" />);

    await act(() => loads[0].onload?.());
    expect(screen.queryByRole('img')).toBeNull();

    await act(() => loads[1].onload?.());
    expect(screen.getByRole('img', { name: '이미지' })).toHaveProperty(
      'src',
      'https://e.com/b.jpg'
    );
  });
});
