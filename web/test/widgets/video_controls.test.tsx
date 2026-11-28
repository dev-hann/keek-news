// @vitest-environment jsdom
import { fireEvent, render, screen } from '@testing-library/react';
import type { ChangeEvent, ComponentProps } from 'react';
import { describe, expect, it, vi } from 'vitest';
import { ControlButton, VideoBottomBar } from '../../src/widgets/video_controls';

type Props = ComponentProps<typeof VideoBottomBar>;

/** A bar under a video that is 5 of 31 seconds in, with 20 seconds loaded. */
function bar(extra: Partial<Props> = {}): Props {
  return {
    playing: true,
    time: 5,
    duration: 31,
    buffered: 20,
    shown: true,
    muted: true,
    fullscreen: false,
    canFullscreen: true,
    onToggle: vi.fn(),
    onScrub: vi.fn(),
    onToggleMute: vi.fn(),
    onToggleFullscreen: vi.fn(),
    ...extra,
  };
}

const slider = (): HTMLInputElement => screen.getByRole('slider', { name: '재생 위치' });

/** The classes of an element one by one: `text-white` is not `hover:text-white`, nor a disabled button's. */
const classes = (element: Element): string[] => element.className.split(/\s+/);

describe('VideoBottomBar', () => {
  it('says the time m:ss / m:ss, and shows where the video is and how far it is loaded', () => {
    const props = bar();
    render(<VideoBottomBar {...props} />);

    expect(screen.getByText('0:05 / 0:31')).toBeTruthy();
    const range = slider();
    expect(range.value).toBe('5');
    expect(range.getAttribute('min')).toBe('0');
    expect(range.getAttribute('max')).toBe('31');
    expect(range.getAttribute('aria-valuetext')).toBe('0:05');
    expect(range.disabled).toBe(false);
    expect(classes(range.parentElement!)).toContain('h-11');

    // The track is the slider's own picture: loaded, then played over it, on a faint line.
    const track = range.nextElementSibling!;
    expect(track.getAttribute('aria-hidden')).toBe('true');
    expect(classes(track)).toContain('bg-white/20');
    const [loaded, played] = track.children as HTMLCollectionOf<HTMLElement>;
    expect(classes(loaded)).toContain('bg-white/30');
    expect(parseFloat(loaded.style.width)).toBeCloseTo((20 / 31) * 100);
    expect(classes(played)).toContain('bg-primary');
    expect(parseFloat(played.style.width)).toBeCloseTo((5 / 31) * 100);
  });

  it('counts the minutes from zero again each hour, as the time of a video is written', () => {
    render(<VideoBottomBar {...bar({ time: 3725, duration: 3661 })} />);

    expect(screen.getByText('2:05 / 1:01')).toBeTruthy();
    expect(slider().getAttribute('aria-valuetext')).toBe('2:05');
  });

  it('has nothing to scrub while the length of the video is not known', () => {
    const { rerender } = render(<VideoBottomBar {...bar({ duration: Number.NaN, time: 0 })} />);
    expect(screen.getByText('0:00 / 0:00')).toBeTruthy();
    expect(slider().disabled).toBe(true);
    expect(slider().getAttribute('aria-valuetext')).toBe('0:00');

    rerender(<VideoBottomBar {...bar({ duration: 0, time: 0 })} />);
    expect(slider().disabled).toBe(true);
    expect(screen.getByText('0:00 / 0:00')).toBeTruthy();
  });

  it('does not let the played or the loaded part run past the end', () => {
    render(<VideoBottomBar {...bar({ time: 40, buffered: 80 })} />);
    const [, played] = slider().nextElementSibling!.children as HTMLCollectionOf<HTMLElement>;
    const [loaded] = slider().nextElementSibling!.children as HTMLCollectionOf<HTMLElement>;
    expect(played.style.width).toBe('100%');
    expect(loaded.style.width).toBe('100%');
  });

  it('names each control by what a tap does, in Korean, over a hidden icon', () => {
    const { rerender } = render(<VideoBottomBar {...bar()} />);

    const buttons = screen.getAllByRole('button');
    expect(buttons.map((button) => button.getAttribute('aria-label'))).toEqual([
      '일시정지',
      '음소거 해제',
      '전체 화면',
    ]);
    for (const button of buttons) {
      expect(classes(button)).toContain('size-11');
      expect(classes(button)).toContain('text-white');
      const icons = button.querySelectorAll('svg');
      expect(icons).toHaveLength(1);
      expect(icons[0].getAttribute('aria-hidden')).toBe('true');
      expect(icons[0].getAttribute('class')).toContain('lucide-');
    }
    expect(buttons[0].querySelector('svg')!.getAttribute('class')).toContain('lucide-pause');
    // The icon says the state, the name the tap.
    expect(buttons[1].querySelector('svg')!.getAttribute('class')).toContain('lucide-volume-x');
    expect(buttons[2].querySelector('svg')!.getAttribute('class')).toContain('lucide-maximize');

    rerender(<VideoBottomBar {...bar({ playing: false, muted: false, fullscreen: true })} />);
    const other = screen.getAllByRole('button');
    expect(other.map((button) => button.getAttribute('aria-label'))).toEqual([
      '재생',
      '음소거',
      '전체 화면 종료',
    ]);
    expect(other[0].querySelector('svg')!.getAttribute('class')).toContain('lucide-play');
    expect(other[1].querySelector('svg')!.getAttribute('class')).toContain('lucide-volume-2');
    expect(other[2].querySelector('svg')!.getAttribute('class')).toContain('lucide-minimize');
  });

  it('offers no full screen where the document cannot', () => {
    render(<VideoBottomBar {...bar({ canFullscreen: false })} />);

    expect(screen.queryByRole('button', { name: '전체 화면' })).toBeNull();
    expect(
      screen.getAllByRole('button').map((button) => button.getAttribute('aria-label'))
    ).toEqual(['일시정지', '음소거 해제']);
  });

  it('is over a black gradient, and shown it is where a tap goes', () => {
    render(<VideoBottomBar {...bar()} />);
    const gradient = slider().closest('.bg-linear-to-b')!;

    expect(classes(gradient)).toContain('from-transparent');
    expect(classes(gradient)).toContain('to-black/70');
    expect(classes(gradient)).toContain('absolute');
    expect(classes(gradient)).toContain('bottom-0');
    // A tap beside a control lands on the bar, not on what is under it.
    expect(classes(gradient)).toContain('pointer-events-auto');
  });

  it('tells what was tapped, and where the video was moved to', () => {
    const onToggle = vi.fn();
    const onToggleMute = vi.fn();
    const onToggleFullscreen = vi.fn();
    // Read as it comes: where the video goes is the player's to say, so the slider waits for it.
    const movedTo: string[] = [];
    const onScrub = vi.fn((event: ChangeEvent<HTMLInputElement>) => {
      movedTo.push(event.target.value);
    });
    render(<VideoBottomBar {...bar({ onToggle, onScrub, onToggleMute, onToggleFullscreen })} />);

    fireEvent.click(screen.getByRole('button', { name: '일시정지' }));
    fireEvent.click(screen.getByRole('button', { name: '음소거 해제' }));
    fireEvent.click(screen.getByRole('button', { name: '전체 화면' }));
    fireEvent.change(slider(), { target: { value: '12' } });

    expect(onToggle).toHaveBeenCalledTimes(1);
    expect(onToggleMute).toHaveBeenCalledTimes(1);
    expect(onToggleFullscreen).toHaveBeenCalledTimes(1);
    expect(movedTo).toEqual(['12']);
  });

  it('hidden, takes neither taps nor the Tab key', () => {
    render(<VideoBottomBar {...bar({ shown: false })} />);

    for (const control of [...screen.getAllByRole('button'), slider()]) {
      expect(control).toHaveProperty('tabIndex', -1);
    }
    expect(classes(slider().parentElement!)).toContain('pointer-events-none');
    for (const button of screen.getAllByRole('button')) {
      expect(classes(button)).toContain('pointer-events-none');
    }
    expect(classes(slider().closest('.bg-linear-to-b')!)).toContain('pointer-events-none');
  });

  it('keeps a touch on the slider to itself, which the page would otherwise take for a pull', () => {
    const onTouch = vi.fn();
    window.addEventListener('touchstart', onTouch);
    window.addEventListener('touchmove', onTouch);
    render(<VideoBottomBar {...bar()} />);

    expect(classes(slider())).toContain('touch-none');
    fireEvent.touchStart(slider());
    fireEvent.touchMove(slider());
    expect(onTouch).not.toHaveBeenCalled();

    // A touch anywhere else on the stage is the page's own to read.
    fireEvent.touchStart(document.body);
    expect(onTouch).toHaveBeenCalledTimes(1);
    window.removeEventListener('touchstart', onTouch);
    window.removeEventListener('touchmove', onTouch);
  });
});

describe('ControlButton', () => {
  it('is a 44px white icon button with a name', () => {
    const onClick = vi.fn();
    render(
      <ControlButton label="음소거" shown onClick={onClick}>
        <svg aria-hidden="true" />
      </ControlButton>
    );
    const button = screen.getByRole('button', { name: '음소거' });

    expect(classes(button)).toContain('size-11');
    expect(classes(button)).toContain('text-white');
    expect(button).toHaveProperty('tabIndex', 0);
    fireEvent.click(button);
    expect(onClick).toHaveBeenCalledTimes(1);
  });

  it('grows where the player gives it a size of its own', () => {
    render(
      <ControlButton label="재생" shown onClick={vi.fn()} className="size-16 rounded-full">
        <svg aria-hidden="true" />
      </ControlButton>
    );

    const tokens = classes(screen.getByRole('button', { name: '재생' }));
    expect(tokens).toContain('size-16');
    expect(tokens).not.toContain('size-11');
    expect(tokens).toContain('rounded-full');
    expect(tokens).not.toContain('rounded-lg');
  });
});
