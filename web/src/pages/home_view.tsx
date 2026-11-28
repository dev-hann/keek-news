import { LoaderCircle, RefreshCw, Settings } from 'lucide-react';
import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react';
import { toast } from 'sonner';
import { cn } from 'cn';
import { Button } from '../components/ui/button';
import { findCommunity, registeredCommunities, type CommunityId } from '../model/community';
import { feedItemKey, type FeedItem } from '../model/feed_item';
import type { ErrorPostDetail } from '../model/post_detail';
import { resolveAbsolute } from '../model/url_builder';
import {
  mergedDetailNotifier,
  mergedFeedNotifier,
  reloadFeed,
  useMergedDetail,
  useMergedFeed,
} from '../provider/merged_feed_provider';
import { useSettings } from '../provider/settings_provider';
import { copyText } from '../utils/clipboard';
import { formatErrorReport } from '../utils/error_report';
import { AppBar } from '../widgets/app_bar';
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
  const [refreshing, setRefreshing] = useState(false);
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

  const refreshSilently = useCallback(async () => {
    if (refreshingNow.current) return;
    refreshingNow.current = true;
    setRefreshing(true);
    try {
      await reloadFeed({ silent: true });
    } finally {
      refreshingNow.current = false;
      setRefreshing(false);
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

  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const scrollToTop = () =>
    window.scrollTo({ top: 0, behavior: reducedMotion ? 'auto' : 'smooth' });

  const onTitleTap = () => {
    if (window.scrollY > 0) scrollToTop();
    else void refreshSilently();
  };

  const onScrollToTopTap = () => {
    window.scrollTo(0, 0);
    void refreshSilently();
  };

  const onCopyLink = async (post: FeedItem) => {
    const copied = await copyText(resolveAbsolute(post.community, post.url));
    if (copied) toast.success('링크를 복사했어요');
    else toast.error('링크를 복사하지 못했습니다');
  };

  const onCopyError = async (post: FeedItem, error: ErrorPostDetail) => {
    const report = formatErrorReport({
      communityLabel: findCommunity(post.community)?.displayName ?? post.community,
      postId: post.id,
      url: resolveAbsolute(post.community, post.url),
      title: post.title,
      failure: error.failure,
      appVersion: __APP_VERSION__,
    });
    const copied = await copyText(report);
    if (copied) toast.success('오류 정보를 복사했어요');
    else toast.error('오류 정보를 복사하지 못했습니다');
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
          return (
            <FeedDetailCard
              key={key}
              post={item}
              detail={entry?.status === 'loaded' ? entry.detail : undefined}
              detailLoading={entry?.status === 'loading'}
              onRetry={() => void detail.retryDetail(key)}
              onCopyLink={() => void onCopyLink(item)}
              onCopyError={(error) => void onCopyError(item, error)}
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
        onTitleTap={onTitleTap}
        actions={
          <>
            <Button
              type="button"
              variant="ghost"
              size="icon"
              aria-label="새로고침"
              title="새로고침"
              disabled={refreshing}
              onClick={() => void refreshSilently()}
              className="size-11"
            >
              <RefreshCw
                aria-hidden="true"
                className={cn('size-5', refreshing && 'animate-spin motion-reduce:animate-none')}
              />
            </Button>
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
          </>
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
    </div>
  );
}
