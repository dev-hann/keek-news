import { MoreHorizontal, X } from 'lucide-react';
import { useEffect, useRef, type SyntheticEvent } from 'react';
import { createPortal } from 'react-dom';
import { Button } from '../components/ui/button';
import type { VideoBlock } from '../model/content_block';
import { videoTarget, type MediaTarget } from '../model/media_target';
import type { VideoId } from '../model/video_id';
import { dialogClosed, dialogOpened, holdsFocus } from '../utils/dialog_stack';
import { useHistoryBack } from '../utils/use_history_back';
import { useLongPress } from '../utils/use_long_press';
import { InlineVideoPlayer } from './inline_video_player';

/** What can take the focus inside the viewer. */
const FOCUSABLE = 'a[href], button:not([disabled]), [tabindex]:not([tabindex="-1"])';

/** Over everything, on black, inside the safe area. */
const FRAME =
  'fixed inset-0 z-50 flex flex-col bg-black pt-[env(safe-area-inset-top)] pb-[env(safe-area-inset-bottom)] select-none [-webkit-touch-callout:none]';

/** The buttons of the viewer, over whatever is shown. */
const CHROME_BUTTON = 'pointer-events-auto size-11 rounded-full bg-black/60 text-white';

interface CommentVideoViewerProps {
  /**
   * Tells this video from every other: the one that may play is the one the
   * playback notifier names. Null only while nothing is shown.
   */
  id: VideoId | null;
  /** The video to show; null, or an `open` that is false: nothing is shown and nothing is put on the history. */
  video: VideoBlock | null;
  open: boolean;
  /** The viewer asks with it to be closed: the page sets `video` to null. */
  onClose: () => void;
  /** Opens the media menu for the video: a long-press on it, or its ⋯ button. */
  onMore?: (target: MediaTarget) => void;
}

/**
 * A comment's video full screen, playing at once and as large as the screen
 * allows. The page only sets `video` to null when `onClose` runs: system Back
 * does that too, before it can leave the page, and before it can close a
 * sheet the viewer sits over.
 */
export function CommentVideoViewer({ id, video, open, onClose, onMore }: CommentVideoViewerProps) {
  const requestClose = useHistoryBack(open && video !== null, onClose);

  if (video === null || id === null || !open) return null;
  return <OpenViewer id={id} video={video} requestClose={requestClose} onMore={onMore} />;
}

/**
 * Touches and clicks stay in the viewer. The page behind listens for touches
 * on the window (its pull to refresh), and a tap inside the viewer would
 * reach, through React, whatever rendered the viewer.
 */
function stay(event: SyntheticEvent): void {
  event.stopPropagation();
}

/**
 * The viewer while it is open. It goes into the document when the viewer
 * opens and out of it when the viewer closes, so each time it opens the
 * video starts over.
 */
function OpenViewer({
  id,
  video,
  requestClose,
  onMore,
}: {
  id: VideoId;
  video: VideoBlock;
  requestClose: () => void;
  onMore?: (target: MediaTarget) => void;
}) {
  const panel = useRef<HTMLDivElement>(null);
  const closeButton = useRef<HTMLButtonElement>(null);
  const press = useLongPress<HTMLDivElement>(
    onMore === undefined ? undefined : () => onMore(videoTarget(video))
  );

  // The page behind cannot scroll while the viewer is open, and the focus starts on 닫기 and stays in.
  useEffect(() => {
    const el = panel.current;
    if (el === null) return;

    // Read before the focus moves into the viewer.
    const opener = document.activeElement as HTMLElement | null;
    const body = document.body;
    const pageScroll = body.style.overflow;
    body.style.overflow = 'hidden';
    dialogOpened(el);

    const focusCloseButton = () => closeButton.current?.focus({ preventScroll: true });
    const onFocusIn = (event: FocusEvent) => {
      // Only the frontmost dialog holds the focus: a sheet opened from the viewer owns it until it closes.
      if (event.target instanceof Node && !el.contains(event.target) && holdsFocus(el)) {
        focusCloseButton();
      }
    };

    document.addEventListener('focusin', onFocusIn);
    focusCloseButton();

    return () => {
      document.removeEventListener('focusin', onFocusIn);
      body.style.overflow = pageScroll;
      dialogClosed(el);
      // The viewer is out of the document by now, so no focus can be left in it.
      opener?.focus({ preventScroll: true });
    };
  }, [requestClose]);

  // The keys are the frontmost dialog's: a sheet opened from the viewer gets its own.
  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      const el = panel.current;
      if (el === null || !holdsFocus(el)) return;
      if (event.key === 'Escape') {
        requestClose();
        return;
      }
      if (event.key !== 'Tab') return;
      // Tab turns back at the last stop of the viewer and at its first, and brings the focus in from outside.
      const stops = Array.from(el.querySelectorAll<HTMLElement>(FOCUSABLE));
      const firstStop = stops[0];
      const lastStop = stops[stops.length - 1];
      if (firstStop === undefined) return;
      const here = document.activeElement;
      const leaving = !el.contains(here) || here === (event.shiftKey ? firstStop : lastStop);
      if (!leaving) return;
      event.preventDefault();
      (event.shiftKey ? lastStop : firstStop).focus();
    };
    document.addEventListener('keydown', onKeyDown);
    return () => document.removeEventListener('keydown', onKeyDown);
  }, [requestClose]);

  return createPortal(
    <div
      ref={panel}
      role="dialog"
      aria-modal="true"
      aria-label="동영상 보기"
      tabIndex={-1}
      className={FRAME}
      onClick={stay}
      onTouchCancel={stay}
      onTouchEnd={stay}
      onTouchMove={stay}
      onTouchStart={stay}
      // The WebView's own menu for a long press on a video: the sheet of the app is what opens.
      onContextMenu={(event) => event.preventDefault()}
    >
      <div className="relative min-h-0 flex-1">
        {/* First in the document as it is on the screen: Tab reaches 닫기 and ⋯ before the controls of the player. */}
        <div className="pointer-events-none absolute inset-x-0 top-0 z-10 flex items-center justify-between p-2">
          <Button
            ref={closeButton}
            type="button"
            variant="ghost"
            size="icon"
            aria-label="닫기"
            onClick={requestClose}
            className={CHROME_BUTTON}
          >
            <X aria-hidden="true" className="size-5" />
          </Button>
          {onMore !== undefined && (
            <Button
              type="button"
              variant="ghost"
              size="icon"
              aria-label="더보기"
              aria-haspopup="dialog"
              onClick={() => onMore(videoTarget(video))}
              className={CHROME_BUTTON}
            >
              <MoreHorizontal aria-hidden="true" className="size-5" />
            </Button>
          )}
        </div>
        {/* The stage is all there is to the viewer, under the chrome: the video is letterboxed in it, not in a box of 16:9. */}
        <div {...press} className="absolute inset-0 z-0">
          <InlineVideoPlayer id={id} video={video} autoStart fill />
        </div>
      </div>
    </div>,
    document.body
  );
}
