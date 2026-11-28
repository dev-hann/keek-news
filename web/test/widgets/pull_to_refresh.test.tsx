// @vitest-environment jsdom
import { act, fireEvent, render } from '@testing-library/react';
import {
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  vi,
  type Mock,
  type MockInstance,
} from 'vitest';
import { PullToRefresh } from '../../src/widgets/pull_to_refresh';

const touch = (type: string, clientY: number) => {
  const event = new Event(type, { bubbles: true, cancelable: true });
  Object.defineProperty(event, 'touches', { value: [{ clientY }] });
  return event;
};

/** A finger that goes down at `from` and moves to `to`. */
function drag(from: number, to: number): void {
  fireEvent(window, touch('touchstart', from));
  fireEvent(window, touch('touchmove', to));
}

describe('PullToRefresh', () => {
  let onRefresh: Mock<() => Promise<void>>;
  let scrollY: MockInstance<() => number>;

  beforeEach(() => {
    onRefresh = vi.fn<() => Promise<void>>().mockResolvedValue(undefined);
    scrollY = vi.spyOn(window, 'scrollY', 'get').mockReturnValue(0);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('refreshes when the top of the page is pulled far enough and let go', async () => {
    render(<PullToRefresh onRefresh={onRefresh} top={56} />);

    drag(100, 400);
    await act(() => fireEvent(window, new Event('touchend')));

    expect(onRefresh).toHaveBeenCalledTimes(1);
  });

  it('does nothing for a short pull', async () => {
    render(<PullToRefresh onRefresh={onRefresh} top={56} />);

    drag(100, 130);
    await act(() => fireEvent(window, new Event('touchend')));

    expect(onRefresh).not.toHaveBeenCalled();
  });

  it('does nothing for a page that is scrolled, even a little', async () => {
    render(<PullToRefresh onRefresh={onRefresh} top={56} />);
    scrollY.mockReturnValue(4);

    drag(100, 400);
    await act(() => fireEvent(window, new Event('touchend')));

    expect(onRefresh).not.toHaveBeenCalled();
  });

  it('does nothing for an upward drag', async () => {
    render(<PullToRefresh onRefresh={onRefresh} top={56} />);

    drag(400, 100);
    await act(() => fireEvent(window, new Event('touchend')));

    expect(onRefresh).not.toHaveBeenCalled();
  });

  it('keeps the page itself from scrolling while it is being pulled', () => {
    render(<PullToRefresh onRefresh={onRefresh} top={56} />);

    const move = touch('touchmove', 400);
    fireEvent(window, touch('touchstart', 100));
    fireEvent(window, move);

    expect(move.defaultPrevented).toBe(true);
  });

  it('does not refresh again while one is running', async () => {
    let finish: () => void = () => undefined;
    onRefresh.mockReturnValue(new Promise<void>((resolve) => (finish = resolve)));
    render(<PullToRefresh onRefresh={onRefresh} top={56} />);

    drag(100, 400);
    await act(() => fireEvent(window, new Event('touchend')));
    drag(100, 400);
    await act(() => fireEvent(window, new Event('touchend')));

    expect(onRefresh).toHaveBeenCalledTimes(1);
    await act(async () => finish());
  });

  it('sits where the page tells it, and above the page when at rest', () => {
    const { container } = render(<PullToRefresh onRefresh={onRefresh} top={112} />);
    const indicator = container.firstElementChild as HTMLElement;

    expect(indicator.style.top).toBe('112px');
    expect(indicator.style.transform).toBe('translateY(-44px)');
  });
});
