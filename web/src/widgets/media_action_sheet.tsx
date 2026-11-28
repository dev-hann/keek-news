import {
  CircleAlert,
  Download,
  ImageDown,
  ImageOff,
  Link,
  LoaderCircle,
  Share2,
  type LucideIcon,
} from 'lucide-react';
import { useEffect, useRef, useState, type ReactNode } from 'react';
import { cn } from 'cn';
import { Button } from '../components/ui/button';
import { Separator } from '../components/ui/separator';
import type { MediaSaveResult } from '../model/media_save_failure';
import { isDownloadable, type MediaTarget } from '../model/media_target';
import { BottomSheet } from './bottom_sheet';

interface MediaActionSheetProps {
  /** What the rows act on. Null, or an `open` that is false: the sheet is not shown. */
  target: MediaTarget | null;
  open: boolean;
  /** The sheet asks with it to be closed: the page sets `target` to null. */
  onClose: () => void;
  /** Copies the address of the media (not the address of the post). */
  onCopy: (target: MediaTarget) => void;
  /** Blocks the image. Given only where blocking an image is possible. */
  onBlock?: (target: MediaTarget) => void;
  /** Saves the picture or the video to the gallery. Given only where the app can. */
  onSave?: (target: MediaTarget) => Promise<MediaSaveResult>;
  /** Offers the picture, the video, or its address to another app. Given only where the app can. */
  onShare?: (target: MediaTarget) => Promise<MediaSaveResult>;
}

/**
 * What one can do with a picture or a video, in a sheet. Only the rows that
 * can do something are in it: 갤러리에 저장 for a picture or a video the app
 * can save, 공유 for any media the app can share, URL 복사 for any of them,
 * and 이미지 차단 for an image where the page can block it.
 *
 * A row runs its action, then asks to be closed where that is what follows.
 * What is said about an action is a toast of the page, which outlives the
 * sheet: the sheet calls none.
 */
export function MediaActionSheet({
  target,
  open,
  onClose,
  onCopy,
  onBlock,
  onSave,
  onShare,
}: MediaActionSheetProps) {
  return (
    <BottomSheet open={open && target !== null} onClose={onClose} label="미디어 메뉴" height="auto">
      {/* Keyed by the target: a row is never left running for another one. */}
      {target !== null && (
        <ActionRows
          key={`${target.kind}:${target.url}`}
          target={target}
          onClose={onClose}
          onCopy={onCopy}
          onBlock={onBlock}
          onSave={onSave}
          onShare={onShare}
        />
      )}
    </BottomSheet>
  );
}

interface ActionRowsProps {
  target: MediaTarget;
  onClose: () => void;
  onCopy: (target: MediaTarget) => void;
  onBlock?: (target: MediaTarget) => void;
  onSave?: (target: MediaTarget) => Promise<MediaSaveResult>;
  onShare?: (target: MediaTarget) => Promise<MediaSaveResult>;
}

/**
 * The rows of the sheet, in the order of the Flutter sheet, with a line
 * between two. This is what the sheet shows, so it lives exactly as long
 * as the sheet does, and so does anything a row is in the middle of.
 */
function ActionRows({ target, onClose, onCopy, onBlock, onSave, onShare }: ActionRowsProps) {
  // The action runs first: to close is for the rows to go.
  const runNow = (action: (target: MediaTarget) => void) => () => {
    action(target);
    onClose();
  };

  const rows: ReactNode[] = [
    onSave !== undefined && isDownloadable(target) && (
      <PendingRow
        key="save"
        icon={target.kind === 'image' ? ImageDown : Download}
        title="갤러리에 저장"
        waitingTitle="저장 중…"
        failedTitle="저장에 실패했어요 · 탭하여 재시도"
        failedName="저장 실패, 탭하여 재시도"
        run={() => onSave(target)}
        onClose={onClose}
      />
    ),
    onShare !== undefined && (
      <PendingRow
        key="share"
        icon={Share2}
        title="공유"
        waitingTitle="준비 중…"
        failedTitle="공유에 실패했어요 · 탭하여 재시도"
        failedName="공유 실패, 탭하여 재시도"
        run={() => onShare(target)}
        onClose={onClose}
      />
    ),
    <ActionRow key="copy" icon={Link} title="URL 복사" onClick={runNow(onCopy)} />,
    // An image only: a video or an embed is not in the scope of the blocklist.
    onBlock !== undefined && target.kind === 'image' && (
      <ActionRow
        key="block"
        icon={ImageOff}
        title="이미지 차단"
        destructive
        onClick={runNow(onBlock)}
      />
    ),
  ].filter(Boolean);

  return (
    <>
      {rows.flatMap((row, index) =>
        index === 0 ? [row] : [<Separator key={`line-${index}`} />, row]
      )}
    </>
  );
}

/** The shape of a row, as a button or as a status: 56px high, its icon and 16px to its title. */
const ROW = 'h-14 w-full items-center gap-4 px-2 text-base';

interface ActionRowProps {
  icon: LucideIcon;
  /** The row's name, as it is read. */
  title: string;
  destructive?: boolean;
  onClick: () => void;
}

function ActionRow({ icon: Icon, title, destructive = false, onClick }: ActionRowProps) {
  return (
    <Button
      type="button"
      variant="ghost"
      onClick={onClick}
      className={cn(
        ROW,
        'justify-start font-normal',
        destructive && 'text-destructive hover:text-destructive'
      )}
    >
      <Icon aria-hidden="true" className="size-6" />
      {title}
    </Button>
  );
}

/** What a row that waits for the app is doing. */
type Phase = 'idle' | 'running' | 'failed';

interface PendingRowProps {
  icon: LucideIcon;
  /** What the row says at rest. Its name too. */
  title: string;
  /** What it says while the app is busy with it. */
  waitingTitle: string;
  /** What it says once it failed, and how it is named then. */
  failedTitle: string;
  failedName: string;
  /** Asks the app for the action, and says how it ended. */
  run: () => Promise<MediaSaveResult>;
  onClose: () => void;
}

/**
 * A row whose action takes time: saving to the gallery, or sharing. While
 * it runs it is a status and not a button, since nothing here can cancel
 * it. It asks the sheet to close once the action is done, or when the
 * reader has to allow something first; any other failure is said here, and
 * a tap tries again.
 */
function PendingRow({
  icon: Icon,
  title,
  waitingTitle,
  failedTitle,
  failedName,
  run,
  onClose,
}: PendingRowProps) {
  const [phase, setPhase] = useState<Phase>('idle');
  // False once the sheet is gone. The promise cannot be cancelled, but what
  // it ends with then changes nothing here, and closes nothing a second time.
  const inSheet = useRef(true);
  useEffect(() => {
    inSheet.current = true;
    return () => {
      inSheet.current = false;
    };
  }, []);

  const start = async () => {
    // No button while it runs: this only stops a tap that was already on its way.
    if (phase === 'running') return;
    setPhase('running');
    const result = await outcomeOf(run);
    if (!inSheet.current) return;
    if (result.ok) {
      onClose();
      return;
    }
    const { type } = result.failure;
    if (type === 'canceled' || type === 'inProgress') {
      setPhase('idle');
    } else if (type === 'permission') {
      onClose();
    } else {
      setPhase('failed');
    }
  };

  if (phase === 'running') {
    return (
      <div role="status" className={cn('flex', ROW)}>
        <LoaderCircle
          aria-hidden="true"
          className="size-6 animate-spin motion-reduce:animate-none"
        />
        {waitingTitle}
      </div>
    );
  }

  if (phase === 'failed') {
    return (
      <Button
        type="button"
        variant="ghost"
        role="alert"
        aria-label={failedName}
        onClick={start}
        className={cn(ROW, 'justify-start font-normal text-destructive hover:text-destructive')}
      >
        <CircleAlert aria-hidden="true" className="size-6" />
        {failedTitle}
      </Button>
    );
  }

  return <ActionRow icon={Icon} title={title} onClick={start} />;
}

/** How the action ended. A promise that broke off is a failure to try again, not a row that waits for ever. */
async function outcomeOf(run: () => Promise<MediaSaveResult>): Promise<MediaSaveResult> {
  try {
    return await run();
  } catch {
    return { ok: false, failure: { type: 'unexpected' } };
  }
}
