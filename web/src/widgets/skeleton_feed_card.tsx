import { Skeleton } from '../components/ui/skeleton';

/** The shape of a post that is still on its way. */
export function SkeletonFeedCard() {
  return (
    <div
      role="progressbar"
      aria-label="게시글 불러오는 중"
      className="flex flex-col rounded-xl bg-card py-0"
    >
      <span className="flex items-center gap-3 p-3">
        <Skeleton className="size-8 rounded-full" />
        <span className="flex flex-1 flex-col gap-2">
          <Skeleton className="h-3 w-44" />
          <Skeleton className="h-2.5 w-30" />
        </span>
      </span>
      <Skeleton className="w-full rounded-none" style={{ height: 'min(600px, 66vh)' }} />
      <span className="flex items-center gap-2 p-3">
        <Skeleton className="size-6" />
        <Skeleton className="h-3 w-10" />
        <Skeleton className="ml-4 size-6" />
        <Skeleton className="ml-auto h-3 w-15" />
      </span>
      <span className="flex flex-col gap-2 px-4 py-2">
        <Skeleton className="h-3.5 w-full" />
        <Skeleton className="h-3 w-50" />
      </span>
    </div>
  );
}
