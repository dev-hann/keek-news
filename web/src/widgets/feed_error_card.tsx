import { CircleAlert, Copy, RefreshCw } from 'lucide-react';
import { Button } from '../components/ui/button';
import { findCommunity } from '../model/community';
import type { Failure } from '../model/failures';
import type { FeedItem } from '../model/feed_item';
import { failureReason } from '../utils/failure_reason';

interface FeedErrorCardProps {
  post: FeedItem;
  failure: Failure;
  onRetry?: () => void;
  onCopyError: () => void;
}

/** Takes the place of a post whose body could not be read. */
export function FeedErrorCard({ post, failure, onRetry, onCopyError }: FeedErrorCardProps) {
  const community = findCommunity(post.community);

  return (
    <div role="alert" className="rounded-xl bg-card px-4 py-4 text-sm ring-1 ring-foreground/10">
      <p className="text-muted-foreground">{community?.displayName ?? post.community}</p>
      <div className="mt-2 flex items-start gap-2">
        <CircleAlert aria-hidden="true" className="mt-0.5 size-5 shrink-0 text-destructive" />
        <p className="min-w-0 flex-1 break-words">불러오기 실패 — {failureReason(failure)}</p>
      </div>
      <div className="mt-3 flex justify-end gap-2">
        {onRetry && (
          <Button type="button" variant="outline" className="h-11" onClick={onRetry}>
            <RefreshCw aria-hidden="true" className="size-4" />
            다시 시도
          </Button>
        )}
        <Button type="button" variant="outline" className="h-11" onClick={() => onCopyError()}>
          <Copy aria-hidden="true" className="size-4" />
          오류 정보 복사
        </Button>
      </div>
    </div>
  );
}
