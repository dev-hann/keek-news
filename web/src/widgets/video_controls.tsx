import { Maximize, Minimize, Pause, Play, Volume2, VolumeX } from 'lucide-react';
import type { ChangeEvent, ReactNode, SyntheticEvent } from 'react';
import { cn } from 'cn';
import { Button } from '../components/ui/button';

/** `m:ss`, the minutes counted from zero again each hour: how the time of a video is written in the app. */
function formatClock(seconds: number): string {
  const whole = Number.isFinite(seconds) ? Math.max(0, Math.floor(seconds)) : 0;
  return `${Math.floor(whole / 60) % 60}:${String(whole % 60).padStart(2, '0')}`;
}

/** Keeps a touch from reaching the listeners the page has on the window: a scrub must not pull the feed. */
function stay(event: SyntheticEvent): void {
  event.stopPropagation();
}

interface ControlButtonProps {
  label: string;
  /** The controls are shown: the button takes taps and the Tab key. */
  shown: boolean;
  onClick: () => void;
  className?: string;
  children: ReactNode;
}

/** A white icon on the black stage of a video, with a 44px target. */
export function ControlButton({ label, shown, onClick, className, children }: ControlButtonProps) {
  return (
    <Button
      type="button"
      variant="ghost"
      size="icon"
      aria-label={label}
      tabIndex={shown ? 0 : -1}
      onClick={onClick}
      className={cn(
        'size-11 text-white hover:bg-white/15 hover:text-white',
        shown ? 'pointer-events-auto' : 'pointer-events-none',
        className
      )}
    >
      {children}
    </Button>
  );
}

interface VideoBottomBarProps {
  /** The play button says what a tap does: 일시정지 while the video plays, 재생 otherwise. */
  playing: boolean;
  /** Where the video is, how long it is, and how far it is loaded, in seconds. A duration of NaN is not known yet. */
  time: number;
  duration: number;
  buffered: number;
  /** The controls are shown: they take taps and the Tab key. */
  shown: boolean;
  muted: boolean;
  fullscreen: boolean;
  /** Whether the document can go full screen at all. */
  canFullscreen: boolean;
  onToggle: () => void;
  onScrub: (event: ChangeEvent<HTMLInputElement>) => void;
  onToggleMute: () => void;
  onToggleFullscreen: () => void;
}

/** Play, the time, where the video is and how far it is loaded, mute and full screen, over a gradient. */
export function VideoBottomBar({
  playing,
  time,
  duration,
  buffered,
  shown,
  muted,
  fullscreen,
  canFullscreen,
  onToggle,
  onScrub,
  onToggleMute,
  onToggleFullscreen,
}: VideoBottomBarProps) {
  const length = Number.isFinite(duration) && duration > 0 ? duration : 0;
  const across = (seconds: number) =>
    `${length > 0 ? Math.min(100, (seconds / length) * 100) : 0}%`;

  return (
    <div
      className={cn(
        'absolute inset-x-0 bottom-0 bg-linear-to-b from-transparent to-black/70 px-1 pt-6 pb-1',
        shown ? 'pointer-events-auto' : 'pointer-events-none'
      )}
    >
      {/* The native slider does the work over a track of our own: a native one cannot say how far the video is loaded.
          Its box is 44px tall for a finger, and lies in the padding above the row instead of in a row of its own:
          the stage of a card is 232px, and half of it is not to be spent on a bar. */}
      <div className={cn('absolute inset-x-1 bottom-12 h-11', !shown && 'pointer-events-none')}>
        <input
          type="range"
          aria-label="재생 위치"
          aria-valuetext={formatClock(time)}
          min={0}
          max={length}
          step="any"
          value={time}
          disabled={length === 0}
          tabIndex={shown ? 0 : -1}
          onChange={onScrub}
          onTouchStart={stay}
          onTouchMove={stay}
          onTouchEnd={stay}
          onTouchCancel={stay}
          className="peer absolute inset-0 h-11 w-full touch-none opacity-0"
        />
        <div
          aria-hidden="true"
          className="pointer-events-none absolute inset-x-0 top-1/2 h-1 -translate-y-1/2 rounded-full bg-white/20 peer-focus-visible:ring-3 peer-focus-visible:ring-ring/50"
        >
          <div
            className="absolute inset-y-0 left-0 rounded-full bg-white/30"
            style={{ width: across(buffered) }}
          />
          <div
            className="absolute inset-y-0 left-0 rounded-full bg-primary"
            style={{ width: across(time) }}
          />
        </div>
      </div>
      {/* Above the slider's box where they overlap: a button is not to be lost under a scrub. */}
      <div className="relative flex items-center">
        <ControlButton label={playing ? '일시정지' : '재생'} shown={shown} onClick={onToggle}>
          {playing ? (
            <Pause aria-hidden="true" className="size-6" />
          ) : (
            <Play aria-hidden="true" className="size-6" />
          )}
        </ControlButton>
        <span className="text-xs tabular-nums text-white">
          {formatClock(time)} / {formatClock(duration)}
        </span>
        <span className="flex-1" />
        <ControlButton
          label={muted ? '음소거 해제' : '음소거'}
          shown={shown}
          onClick={onToggleMute}
        >
          {/* The icon shows the state, the name the tap: as the play button does. */}
          {muted ? (
            <VolumeX aria-hidden="true" className="size-6" />
          ) : (
            <Volume2 aria-hidden="true" className="size-6" />
          )}
        </ControlButton>
        {canFullscreen && (
          <ControlButton
            label={fullscreen ? '전체 화면 종료' : '전체 화면'}
            shown={shown}
            onClick={onToggleFullscreen}
          >
            {fullscreen ? (
              <Minimize aria-hidden="true" className="size-6" />
            ) : (
              <Maximize aria-hidden="true" className="size-6" />
            )}
          </ControlButton>
        )}
      </div>
    </div>
  );
}
