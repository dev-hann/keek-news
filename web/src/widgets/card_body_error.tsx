import { CircleAlert, RefreshCw } from 'lucide-react';
import { Button } from '../components/ui/button';
import type { Failure } from '../model/failures';
import { failureReason, isPostGone } from '../utils/failure_reason';

interface CardBodyErrorProps {
  failure: Failure;
  onRetry?: () => void;
}

/**
 * Why the body of a post is missing, inside its card. The card stays, with
 * what the listing knows about the post: for a saved post, which an error
 * card would leave without its title.
 */
export function CardBodyError({ failure, onRetry }: CardBodyErrorProps) {
  if (isPostGone(failure)) {
    return (
      <p role="alert" className="flex items-start gap-2 pt-2 text-sm text-muted-foreground">
        <CircleAlert aria-hidden="true" className="mt-0.5 size-4 shrink-0" />
        <span className="min-w-0 flex-1 break-words">삭제되었거나 비공개된 게시물이에요</span>
      </p>
    );
  }

  const offline = failure.kind === 'NetworkFailure';
  return (
    <div role="alert" className="pt-2 text-sm">
      <p className="flex items-start gap-2">
        <CircleAlert aria-hidden="true" className="mt-0.5 size-4 shrink-0 text-destructive" />
        <span className="min-w-0 flex-1 break-words">
          {offline
            ? '연결할 수 없어 본문을 불러올 수 없어요'
            : `불러오기 실패 — ${failureReason(failure)}`}
        </span>
      </p>
      {/* What is shown was saved earlier: it may not be what the post says now. */}
      {offline && <p className="pt-1 text-muted-foreground">저장한 때의 글만 보여요</p>}
      {onRetry && (
        <Button type="button" variant="outline" className="mt-2 h-11" onClick={onRetry}>
          <RefreshCw aria-hidden="true" className="size-4" />
          다시 시도
        </Button>
      )}
    </div>
  );
}
