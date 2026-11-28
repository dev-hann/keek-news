import { ChevronDown, LoaderCircle } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import { cn } from 'cn';
import { PULL_MAX, pullDistance, pullReleases } from '../utils/pull_to_refresh';

/** How far the indicator travels, in pixels: the height of its own box. */
const INDICATOR_TRAVEL = 44;

interface PullToRefreshProps {
  /** Runs once a pull is let go past the trigger. The wait ends when it has ended. */
  onRefresh: () => Promise<void>;
  /** How far the indicator sits from the top of the screen, in pixels: under the bars that are there. */
  top: number;
}

/**
 * Pulling the top of the page down loads it again. Only a page at its very
 * top can be pulled. The indicator shows right under the app bar.
 */
export function PullToRefresh({ onRefresh, top }: PullToRefreshProps) {
  const [distance, setDistance] = useState(0);
  const [armed, setArmed] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const pull = useRef({ startY: -1, active: false, armed: false });
  const busy = useRef(false);

  useEffect(() => {
    const onTouchStart = (event: TouchEvent) => {
      const state = pull.current;
      state.active = false;
      state.startY = !busy.current && window.scrollY <= 0 ? event.touches[0].clientY : -1;
    };

    const onTouchMove = (event: TouchEvent) => {
      const state = pull.current;
      if (state.startY < 0) return;
      const delta = event.touches[0].clientY - state.startY;
      if (!state.active) {
        // A pull begins only downwards from the very top, after a little slop.
        if (delta <= 0 || window.scrollY > 0) return;
        state.active = true;
      }
      // Keeps the page itself from scrolling behind the indicator.
      event.preventDefault();
      state.armed = pullReleases(delta);
      setArmed(state.armed);
      setDistance(pullDistance(delta));
    };

    const onTouchEnd = async () => {
      const state = pull.current;
      const release = state.active && state.armed;
      state.active = false;
      state.startY = -1;
      if (!release) {
        setArmed(false);
        setDistance(0);
        return;
      }
      busy.current = true;
      setRefreshing(true);
      try {
        await onRefresh();
      } finally {
        busy.current = false;
        setRefreshing(false);
        setArmed(false);
        setDistance(0);
      }
    };

    const onTouchCancel = () => {
      const state = pull.current;
      state.active = false;
      state.startY = -1;
      setArmed(false);
      setDistance(0);
    };

    window.addEventListener('touchstart', onTouchStart, { passive: true });
    // Not passive: a pull has to keep the page from scrolling.
    window.addEventListener('touchmove', onTouchMove, { passive: false });
    window.addEventListener('touchend', onTouchEnd);
    window.addEventListener('touchcancel', onTouchCancel);
    return () => {
      window.removeEventListener('touchstart', onTouchStart);
      window.removeEventListener('touchmove', onTouchMove);
      window.removeEventListener('touchend', onTouchEnd);
      window.removeEventListener('touchcancel', onTouchCancel);
    };
  }, [onRefresh]);

  const travel = refreshing
    ? 0
    : (Math.min(distance, PULL_MAX) / PULL_MAX) * INDICATOR_TRAVEL - INDICATOR_TRAVEL;

  return (
    <>
      <div
        aria-hidden="true"
        className="pointer-events-none fixed inset-x-0 z-10 flex h-11 items-center justify-center transition-transform duration-100 ease-in-out motion-reduce:transition-none"
        style={{ top, transform: `translateY(${travel}px)` }}
      >
        {refreshing ? (
          <LoaderCircle className="size-6 animate-spin text-muted-foreground motion-reduce:animate-none" />
        ) : (
          <ChevronDown
            className={cn(
              'size-6 text-muted-foreground transition-transform duration-100 ease-in-out motion-reduce:transition-none',
              armed && 'rotate-180 text-primary'
            )}
          />
        )}
      </div>
      <span role="status" className="sr-only">
        {refreshing ? '새로고침 중' : ''}
      </span>
    </>
  );
}
