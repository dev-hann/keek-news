import { X } from 'lucide-react';
import { useEffect, useRef, type ReactNode, type RefObject, type SyntheticEvent } from 'react';
import { createPortal } from 'react-dom';
import { cn } from 'cn';
import { Button } from '../components/ui/button';
import { Separator } from '../components/ui/separator';
import { dialogClosed, dialogOpened, holdsFocus } from '../utils/dialog_stack';
import { useHistoryBack } from '../utils/use_history_back';

/** What can take the focus inside the sheet. */
const FOCUSABLE = 'a[href], button:not([disabled]), [tabindex]:not([tabindex="-1"])';

/**
 * Touches and clicks stay in the sheet. The page behind listens for touches
 * on the window (its pull to refresh), and a tap inside the sheet would
 * reach, through React, whatever rendered the sheet.
 */
function stay(event: SyntheticEvent): void {
  event.stopPropagation();
}

interface BottomSheetProps {
  /** False: nothing is rendered, and nothing is put on the history. */
  open: boolean;
  /** The sheet asks with it to be closed: the page sets `open` to false. */
  onClose: () => void;
  /** What the sheet is, for a screen reader: the dialog's name. */
  label: string;
  /** Shown at the top of the sheet. A sheet of a few rows can leave it out. */
  title?: string;
  /** `tall` (the default) is most of the screen, what a list needs; `auto` is as high as its rows. */
  height?: 'tall' | 'auto';
  /** What gets the focus back when the sheet closes. Left out: what has it when the sheet opens. */
  returnFocusTo?: RefObject<HTMLElement | null>;
  children: ReactNode;
}

/**
 * A sheet over the page, at the bottom of the screen: what every sheet of
 * the app is made of. The page only sets `open` to false when `onClose`
 * runs: system Back does that too, before it can leave the page.
 *
 * The focus starts on 닫기 and stays in the sheet as long as the sheet is
 * the frontmost dialog: one opened from it holds the focus instead, and
 * takes it back when it closes.
 */
export function BottomSheet({
  open,
  onClose,
  label,
  title,
  height = 'tall',
  returnFocusTo,
  children,
}: BottomSheetProps) {
  const requestClose = useHistoryBack(open, onClose);
  const panel = useRef<HTMLDivElement>(null);
  const closeButton = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    const sheet = panel.current;
    if (!open || sheet === null) return;

    // Read before the focus moves into the sheet.
    const opener = returnFocusTo?.current ?? (document.activeElement as HTMLElement | null);
    const body = document.body;
    const pageScroll = body.style.overflow;
    body.style.overflow = 'hidden';
    dialogOpened(sheet);

    const focusCloseButton = () => closeButton.current?.focus({ preventScroll: true });
    const onFocusIn = (event: FocusEvent) => {
      if (!holdsFocus(sheet)) return;
      if (event.target instanceof Node && !sheet.contains(event.target)) focusCloseButton();
    };
    const onKeyDown = (event: KeyboardEvent) => {
      // A dialog opened from this sheet is in front: the keyboard is its own, as the focus is.
      if (!holdsFocus(sheet)) return;
      if (event.key === 'Escape') {
        requestClose();
        return;
      }
      if (event.key !== 'Tab') return;
      // Tab turns back at the last stop of the sheet and at its first, and
      // brings the focus in from outside.
      const stops = Array.from(sheet.querySelectorAll<HTMLElement>(FOCUSABLE));
      const first = stops[0];
      const last = stops[stops.length - 1];
      if (first === undefined || last === undefined) return;
      const current = document.activeElement;
      const leaving = !sheet.contains(current) || current === (event.shiftKey ? first : last);
      if (!leaving) return;
      event.preventDefault();
      (event.shiftKey ? last : first).focus();
    };

    document.addEventListener('focusin', onFocusIn);
    document.addEventListener('keydown', onKeyDown);
    focusCloseButton();

    return () => {
      document.removeEventListener('focusin', onFocusIn);
      document.removeEventListener('keydown', onKeyDown);
      body.style.overflow = pageScroll;
      dialogClosed(sheet);
      // The sheet is out of the document by now, so no focus can be left in it.
      opener?.focus({ preventScroll: true });
    };
  }, [open, requestClose, returnFocusTo]);

  if (!open) return null;

  return createPortal(
    <div
      className="fixed inset-0 z-50 flex flex-col justify-end"
      onClick={stay}
      onTouchCancel={stay}
      onTouchEnd={stay}
      onTouchMove={stay}
      onTouchStart={stay}
    >
      <div aria-hidden="true" className="absolute inset-0 bg-black/60" onClick={requestClose} />
      <div
        ref={panel}
        role="dialog"
        aria-modal="true"
        aria-label={label}
        tabIndex={-1}
        className={cn(
          'relative flex w-full animate-in slide-in-from-bottom duration-250 ease-out motion-reduce:animate-none flex-col rounded-t-xl border-t bg-card',
          height === 'tall' ? 'h-[70dvh]' : 'max-h-[85dvh]'
        )}
      >
        <div
          className={cn(
            'flex shrink-0 items-center gap-2 px-4',
            title === undefined && 'justify-end'
          )}
        >
          {title !== undefined && (
            <h2 className="min-w-0 flex-1 truncate text-lg font-semibold">{title}</h2>
          )}
          <Button
            ref={closeButton}
            type="button"
            variant="ghost"
            size="icon"
            aria-label="닫기"
            onClick={requestClose}
            className="size-11"
          >
            <X aria-hidden="true" className="size-5" />
          </Button>
        </div>
        <Separator className="shrink-0" />
        <div
          className={cn(
            'min-h-0 overflow-y-auto overscroll-contain px-4 pb-[env(safe-area-inset-bottom)]',
            height === 'tall' && 'flex-1'
          )}
        >
          {children}
        </div>
      </div>
    </div>,
    document.body
  );
}
