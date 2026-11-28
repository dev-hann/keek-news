import { LoaderCircle, Settings } from 'lucide-react';
import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react';
import { Button } from '../components/ui/button';
import { registeredCommunities, type CommunityId } from '../model/community';
import { feedItemKey } from '../model/feed_item';
import { commentVideoId } from '../model/video_id';
import { useBlockedImages } from '../provider/blocked_images_provider';
import { useBookmarks } from '../provider/bookmark_provider';
import { useCommentsSheet } from '../provider/comments_sheet';
import {
  mergedDetailNotifier,
  mergedFeedNotifier,
  reloadFeed,
  useMergedDetail,
  useMergedFeed,
} from '../provider/merged_feed_provider';
import { useMediaOverlays } from '../provider/media_actions';
import { copyPostError, copyPostLink, toggleBookmark } from '../provider/post_actions';
import { useSettings } from '../provider/settings_provider';
import { filterBlockedPostDetail } from '../utils/blocked_image_filter';
import { CommentsSheet } from '../widgets/comments_sheet';
import { AppBar } from '../widgets/app_bar';
import { CommentVideoViewer } from '../widgets/comment_video_viewer';
import { ImageViewer } from '../widgets/image_viewer';
import { MediaActionSheet } from '../widgets/media_action_sheet';
import { CommunityTabBar } from '../widgets/community_tab_bar';
import { EmptyStateView } from '../widgets/empty_state_view';
import { ErrorStateView } from '../widgets/error_state_view';
import { FeedDetailCard } from '../widgets/feed_detail_card';
import { PullToRefresh } from '../widgets/pull_to_refresh';
import { ScrollToTopButton } from '../widgets/scroll_to_top_button';
import { SkeletonFeedCard } from '../widgets/skeleton_feed_card';

/** The button to go back to the top shows once the page is scrolled this far. */
const SCROLL_TOP_AFTER = 600;
/** The next page is asked for this far down the list. */
const NEXT_PAGE_AT = 0.85;
const SKELETON_CARDS = 4;
/** Height of the app bar, and of the community tab bar when there is one. */
const APP_BAR_HEIGHT = 56;
const TAB_BAR_HEIGHT = 56;

interface HomeViewProps {
  onOpenSettings: () => void;
}

export function HomeView({ onOpenSettings }: HomeViewProps) {
  const feed = useMergedFeed();
  const details = useMergedDetail();
  const enabled = useSettings();
  const [tabId, setTabId] = useState<CommunityId | null>(null);
  const [showScrollTop, setShowScrollTop] = useState(false);
  const refreshingNow = useRef(false);
  const loadingMore = useRef(false);

  const shown = registeredCommunities.filter((community) => enabled.has(community.id));
  const selected = shown.find((community) => community.id === tabId) ?? shown[0];
  // With more than one community on, the selected tab picks what is shown.
  const visibleItems =
    shown.length > 1 && selected
      ? feed.items.filter((item) => item.community === selected.id)
      : feed.items;
  const detail = mergedDetailNotifier();
  const bookmarks = useBookmarks();
  const blockedUrls = new Set(useBlockedImages().map((image) => image.url));
  const sheet = useCommentsSheet(details, blockedUrls);
  const media = useMediaOverlays(blockedUrls);

  const refreshSilently = useCallback(async () => {
    if (refreshingNow.current) return;
    refreshingNow.current = true;
    try {
      await reloadFeed({ silent: true });
    } finally {
      refreshingNow.current = false;
    }
  }, []);

  useEffect(() => {
    const onScroll = () => {
      setShowScrollTop(window.scrollY > SCROLL_TOP_AFTER);
      if (loadingMore.current) return;
      const scrollable = document.documentElement.scrollHeight - window.innerHeight;
      if (scrollable <= 0 || window.scrollY < scrollable * NEXT_PAGE_AT) return;
      loadingMore.current = true;
      void mergedFeedNotifier()
        .fetchNextPage()
        .finally(() => {
          loadingMore.current = false;
        });
    };
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  // A first page that does not fill the screen gives nothing to scroll: ask for the next page directly.
  useEffect(() => {
    if (feed.isLoading || !feed.hasMore) return;
    if (document.documentElement.scrollHeight > window.innerHeight) return;
    void mergedFeedNotifier().fetchNextPage();
  }, [feed.isLoading, feed.hasMore, feed.items.length]);

  useEffect(() => {
    visibleItems.forEach((item) => {
      void detail.fetchDetail(feedItemKey(item));
    });
  }, [detail, visibleItems]);

  // Back to the top, and the first page loads again: what was scrolled away may be old by now.
  const onScrollToTopTap = () => {
    window.scrollTo(0, 0);
    void refreshSilently();
  };

  let content: ReactNode;
  if (feed.isLoading) {
    content = Array.from({ length: SKELETON_CARDS }, (_, index) => (
      <SkeletonFeedCard key={index} />
    ));
  } else if (feed.error !== null) {
    content = (
      <ErrorStateView
        message="피드를 불러올 수 없습니다."
        onRetry={() => void reloadFeed({ silent: false })}
      />
    );
  } else if (visibleItems.length === 0) {
    content = <EmptyStateView message="게시글이 없습니다." />;
  } else {
    content = (
      <>
        {visibleItems.map((item) => {
          const key = feedItemKey(item);
          const entry = details.get(key);
          const shown =
            entry?.status === 'loaded'
              ? (filterBlockedPostDetail(entry.detail, blockedUrls) ?? undefined)
              : undefined;
          return (
            <FeedDetailCard
              key={key}
              post={item}
              detail={shown}
              detailLoading={entry?.status === 'loading'}
              onRetry={() => void detail.retryDetail(key)}
              onCopyLink={() => void copyPostLink(item)}
              onCopyError={(error) => void copyPostError(item, error)}
              bookmarked={bookmarks.some(
                (bookmark) => bookmark.community === item.community && bookmark.id === item.id
              )}
              onToggleBookmark={() => void toggleBookmark(item)}
              onOpenComments={() => sheet.open(key)}
              onOpenImage={(index) =>
                media.openImage(shown?.status === 'loaded' ? shown.imageUrls : [], index)
              }
              onMore={media.openMore}
            />
          );
        })}
        {(feed.hasMore || feed.isLoadingMore) && (
          <p role="status" className="flex justify-center py-4 text-muted-foreground">
            <LoaderCircle
              aria-hidden="true"
              className="size-6 animate-spin motion-reduce:animate-none"
            />
            <span className="sr-only">게시글을 더 불러오는 중</span>
          </p>
        )}
      </>
    );
  }

  const hasTabs = shown.length > 1 && selected !== undefined;

  return (
    <div className="min-h-dvh bg-background">
      <AppBar
        title={selected?.displayName ?? ''}
        actions={
          <Button
            type="button"
            variant="ghost"
            size="icon"
            aria-label="설정"
            title="설정"
            onClick={onOpenSettings}
            className="size-11"
          >
            <Settings aria-hidden="true" className="size-5" />
          </Button>
        }
      />
      {hasTabs && (
        <CommunityTabBar
          communities={shown}
          selectedId={selected.id}
          onSelect={(id) => {
            setTabId(id);
            window.scrollTo(0, 0);
          }}
        />
      )}
      <PullToRefresh
        onRefresh={refreshSilently}
        top={APP_BAR_HEIGHT + (hasTabs ? TAB_BAR_HEIGHT : 0)}
      />
      <main className="mx-auto flex w-full max-w-2xl flex-col gap-3 pt-3 pb-16">{content}</main>
      <ScrollToTopButton visible={showScrollTop} onClick={onScrollToTopTap} />
      <CommentsSheet
        comments={sheet.comments}
        open={sheet.isOpen}
        onClose={sheet.close}
        onOpenImage={media.openImage}
        onOpenVideo={(video) => {
          if (sheet.key !== null) media.openVideo(commentVideoId(sheet.key), video);
        }}
        onMore={media.openMore}
      />
      <CommentVideoViewer {...media.commentVideo} />
      <ImageViewer {...media.viewer} />
      <MediaActionSheet {...media.menu} />
    </div>
  );
}
