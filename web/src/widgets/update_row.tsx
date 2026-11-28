import { CircleAlert, Info, LoaderCircle } from 'lucide-react';
import { cn } from 'cn';
import { Button } from '../components/ui/button';
import type { AppRelease, UpdateState, UpdateStatus } from '../model/app_update';

/** What a status says. These words are what a screen reader hears, so they are chosen for that. */
const WORDS: Partial<Record<UpdateStatus, string>> = {
  checking: '확인 중…',
  upToDate: '최신 버전',
  downloadFailed: '다운로드 실패',
  ready: '다운로드 완료',
  permissionNeeded: '설치 권한 필요',
  installFailed: '설치 실패',
  checkFailed: '확인 실패',
};

/** The statuses that say a failure: heard once, when they appear. */
const FAILED = new Set<UpdateStatus>(['downloadFailed', 'installFailed', 'checkFailed']);

/** The statuses while a version can still be read about: the row keeps the line, so a tap moves nothing. */
const NOTES_LINE = new Set<UpdateStatus>([
  'available',
  'downloading',
  'downloadFailed',
  'ready',
  'permissionNeeded',
  'installFailed',
]);

/** A label in orange, and still orange while pressed: the action takes the reader forward. */
const FORWARD = 'text-primary hover:text-primary';

function wordsOf(
  status: UpdateStatus,
  release: AppRelease | null,
  percent: number | null
): string | null {
  if (status === 'available') return `v${release?.version} 사용 가능`;
  if (status === 'downloading') return percent === null ? '다운로드 중…' : '다운로드 중';
  return WORDS[status] ?? null;
}

interface UpdateRowProps {
  /** What is known about a new version of the app. */
  state: UpdateState;
  onDownload: () => void;
  onCancel: () => void;
  onRetry: () => void;
  onInstall: () => void;
  onOpenInstallSettings: () => void;
}

/**
 * The version row of the settings. It says what is installed and whether a newer version is
 * there, and carries the one button that gets it: the row is never a button itself.
 */
export function UpdateRow({
  state,
  onDownload,
  onCancel,
  onRetry,
  onInstall,
  onOpenInstallSettings,
}: UpdateRowProps) {
  const { status, version, support, release, percent } = state;
  // Until the shell said what is installed, the row shows nothing but its title: it never names
  // a version the reader may not have. A reading that failed says so, without a number.
  const read = version !== null;
  const failed = FAILED.has(status);
  const words = read || failed ? wordsOf(status, release, percent) : null;
  const notesUrl =
    read && release !== null && NOTES_LINE.has(status) && support !== 'manual'
      ? release.pageUrl
      : null;

  const icon =
    !read || (!failed && status !== 'checking') ? (
      <Info className="size-5" />
    ) : failed ? (
      <CircleAlert className="size-5" />
    ) : (
      <LoaderCircle className="size-5 animate-spin motion-reduce:animate-none" />
    );

  const action =
    read || failed
      ? actionOf(state, { onDownload, onCancel, onRetry, onInstall, onOpenInstallSettings })
      : null;

  return (
    <div className="flex min-h-12 w-full items-center gap-3 px-4 py-3 text-left text-base">
      <span aria-hidden="true" className={cn('shrink-0', failed && 'text-destructive')}>
        {icon}
      </span>
      <span className="min-w-0 flex-1">
        <span className="block">버전</span>
        {/* The line is held while empty: the row keeps its height from its first frame. */}
        <span className="mt-0.5 block min-h-5 text-sm break-words text-muted-foreground">
          {read && `v${version}`}
          {read && words && ' · '}
          {words &&
            (failed ? (
              // A failure is a new element: changing the role of one on screen is not announced.
              <span key="alert" role="alert">
                {words}
              </span>
            ) : (
              <span key="status" role="status">
                {words}
              </span>
            ))}
          {words !== null && status === 'downloading' && percent !== null && (
            <>
              {' '}
              <span className="tabular-nums">{percent}%</span>
            </>
          )}
        </span>
        {notesUrl && (
          <a
            href={notesUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="flex min-h-11 items-center text-sm text-primary underline"
          >
            업데이트 내용
          </a>
        )}
      </span>
      {action?.link ? (
        <Button asChild variant="outline" className={cn('h-11', FORWARD)}>
          <a href={release?.pageUrl} target="_blank" rel="noopener noreferrer">
            {action.label}
          </a>
        </Button>
      ) : action ? (
        <Button
          type="button"
          variant="outline"
          className={cn('h-11', action.forward && FORWARD)}
          onClick={action.onClick}
        >
          {action.label}
        </Button>
      ) : null}
    </div>
  );
}

/** The one button of the row: its label and what it does follow the status. */
function actionOf(
  { status, support }: UpdateState,
  taps: Pick<
    UpdateRowProps,
    'onDownload' | 'onCancel' | 'onRetry' | 'onInstall' | 'onOpenInstallSettings'
  >
):
  | { label: string; link: true }
  | { label: string; link: false; forward: boolean; onClick: () => void }
  | null {
  switch (status) {
    case 'available':
      // A shell that cannot download sends the reader to the Release page instead.
      return support === 'manual'
        ? { label: 'GitHub에서 받기', link: true }
        : { label: '업데이트', link: false, forward: true, onClick: taps.onDownload };
    case 'downloading':
      return { label: '취소', link: false, forward: false, onClick: taps.onCancel };
    case 'downloadFailed':
    case 'installFailed':
    case 'checkFailed':
      return { label: '다시 시도', link: false, forward: false, onClick: taps.onRetry };
    case 'ready':
      return { label: '설치', link: false, forward: true, onClick: taps.onInstall };
    case 'permissionNeeded':
      return {
        label: '설정 열기',
        link: false,
        forward: true,
        onClick: taps.onOpenInstallSettings,
      };
    default:
      return null;
  }
}
