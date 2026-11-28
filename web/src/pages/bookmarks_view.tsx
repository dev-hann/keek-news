import { Bookmark } from 'lucide-react';
import { useEffect } from 'react';
import { feedItemFromBookmark, feedItemKey } from '../model/feed_item';
import { useBlockedImages } from '../provider/blocked_images_provider';
import { useBookmarks } from '../provider/bookmark_provider';
import { mergedDetailNotifier, useMergedDetail } from '../provider/merged_feed_provider';
import { copyPostError, copyPostLink, toggleBookmark } from '../provider/post_actions';
import { filterBlockedPostDetail } from '../utils/blocked_image_filter';
import { AppBar } from '../widgets/app_bar';
import { EmptyStateView } from '../widgets/empty_state_view';
import { FeedDetailCard } from '../widgets/feed_detail_card';

interface BookmarksViewProps {
  onBack: () => void;
}

/** The posts the user saved, most recently saved first. */
export function BookmarksView({ onBack }: BookmarksViewProps) {
  const bookmarks = useBookmarks();
  const details = useMergedDetail();
  const blockedUrls = new Set(useBlockedImages().map((image) => image.url));
  const detail = mergedDetailNotifier();

  useEffect(() => {
    bookmarks.forEach((bookmark) => {
      void detail.fetchDetail(feedItemKey(feedItemFromBookmark(bookmark)));
    });
  }, [detail, bookmarks]);

  return (
    <div className="min-h-dvh bg-background">
      <AppBar title="저장함" onBack={onBack} />
      <main className="mx-auto flex w-full max-w-2xl flex-col gap-3 pt-3 pb-16">
        {bookmarks.length === 0 ? (
          <EmptyStateView
            message="저장한 게시물이 없어요"
            hint="좋아하는 글을 북마크해 보세요"
            icon={Bookmark}
          />
        ) : (
          bookmarks.map((bookmark) => {
            const item = feedItemFromBookmark(bookmark);
            const key = feedItemKey(item);
            const entry = details.get(key);
            return (
              <FeedDetailCard
                key={key}
                post={item}
                detail={
                  filterBlockedPostDetail(
                    entry?.status === 'loaded' ? entry.detail : null,
                    blockedUrls
                  ) ?? undefined
                }
                detailLoading={entry?.status === 'loading'}
                keepOnBodyError
                onRetry={() => void detail.retryDetail(key)}
                onCopyLink={() => void copyPostLink(item)}
                onCopyError={(error) => void copyPostError(item, error)}
                bookmarked
                onToggleBookmark={() => void toggleBookmark(item)}
              />
            );
          })
        )}
      </main>
    </div>
  );
}
