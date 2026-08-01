import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keek_news/const/app_durations.dart';
import 'package:keek_news/const/app_spacing.dart';
import 'package:keek_news/model/bookmark.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/provider/bookmark_provider.dart';
import 'package:keek_news/provider/feed_video_playback_provider.dart';
import 'package:keek_news/provider/merged_feed_provider.dart';
import 'package:keek_news/service/video_playback_controller.dart';
import 'package:keek_news/widgets/community_tab_bar.dart';
import 'package:keek_news/widgets/empty_state_view.dart';
import 'package:keek_news/widgets/error_state_view.dart';
import 'package:keek_news/widgets/feed_card_entry.dart';
import 'package:keek_news/widgets/loading_indicator.dart';
import 'package:keek_news/widgets/scroll_to_top_button.dart';
import 'package:keek_news/widgets/skeleton_feed_card.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeView> {
  final ScrollController _controller = ScrollController();
  final ValueNotifier<bool> _showScrollTop = ValueNotifier(false);
  bool _isLoadingMore = false;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    _showScrollTop.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;

    final shouldShow = pos.pixels > 600;
    if (shouldShow != _showScrollTop.value) {
      _showScrollTop.value = shouldShow;
    }

    if (_isLoadingMore) return;
    if (pos.maxScrollExtent <= 0) return;
    if (pos.pixels < pos.maxScrollExtent * 0.85) return;

    _isLoadingMore = true;
    Future.microtask(() {
      ref.read(mergedFeedProvider.notifier).fetchNextPage().whenComplete(() {
        _isLoadingMore = false;
      });
    });
  }

  void _switchTab(int index) {
    if (index == _tabIndex) {
      _onTopTap();
      return;
    }
    setState(() => _tabIndex = index);
    if (_controller.hasClients) _controller.jumpTo(0);
  }

  void _scrollToTop() {
    if (!_controller.hasClients || _controller.offset <= 0) return;
    _controller.animateTo(
      0,
      duration: AppDurations.medium,
      curve: AppCurves.decelerate,
    );
  }

  void _onTopTap() {
    if (_controller.hasClients && _controller.offset > 0) {
      _scrollToTop();
    } else {
      ref.read(mergedFeedProvider.notifier).refresh();
    }
  }

  List<FeedItem> _filterItems(List<FeedItem> items) {
    final selected = communities[_tabIndex].id;
    return items.where((e) => e.community == selected).toList();
  }

  void _ensureDetailsLoaded(List<FeedItem> items, MergedDetailMap details) {
    for (final item in items) {
      final key = (community: item.community, id: item.id);
      if (!details.containsKey(key)) {
        Future.microtask(
          () => ref.read(mergedDetailProvider.notifier).fetchDetail(key),
        );
      }
    }
  }

  PostDetail? _resolveDetail(MergedDetailMap details, FeedItem item) {
    final av = details[(community: item.community, id: item.id)];
    return av?.whenOrNull(data: (either) => either.fold((_) => null, (d) => d));
  }

  bool _resolveDetailLoading(MergedDetailMap details, FeedItem item) {
    final av = details[(community: item.community, id: item.id)];
    return av?.isLoading ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(mergedFeedProvider);
    final bookmarks = ref.watch(bookmarkProvider);
    final details = ref.watch(mergedDetailProvider);
    final videoController = ref.watch(videoPlaybackControllerProvider);
    final visibleItems = _filterItems(feedState.items);
    _ensureDetailsLoaded(visibleItems, details);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _onTopTap,
          behavior: HitTestBehavior.opaque,
          child: Text(communities[_tabIndex].displayName),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '설정',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          CommunityTabBar(selectedIndex: _tabIndex, onChanged: _switchTab),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.read(mergedFeedProvider.notifier).fetch(),
              child: _buildBody(
                feedState,
                visibleItems,
                bookmarks,
                details,
                videoController,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: _showScrollTop,
        builder: (context, show, _) =>
            ScrollToTopButton(visible: show, onTap: _scrollToTop),
      ),
    );
  }

  Widget _buildBody(
    MergedFeedState state,
    List<FeedItem> visibleItems,
    List<Bookmark> bookmarks,
    MergedDetailMap details,
    VideoPlaybackController videoController,
  ) {
    if (state.isLoading) {
      return _buildSkeleton();
    }
    if (state.error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          ErrorStateView(
            message: state.error!,
            onRetry: () => ref.read(mergedFeedProvider.notifier).fetch(),
          ),
        ],
      );
    }
    if (visibleItems.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          EmptyStateView(message: '게시글이 없습니다.'),
        ],
      );
    }

    final extra = (state.hasMore || state.isLoadingMore) ? 1 : 0;

    return ListView.builder(
      controller: _controller,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: visibleItems.length + extra,
      itemBuilder: (context, index) {
        if (index == visibleItems.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: LoadingIndicator(),
          );
        }
        final item = visibleItems[index];
        return RepaintBoundary(
          child: FeedCardEntry(
            post: item,
            detail: _resolveDetail(details, item),
            detailLoading: _resolveDetailLoading(details, item),
            isBookmarked: bookmarks.any(
              (b) => b.community == item.community && b.id == item.id,
            ),
            controller: videoController,
            onBookmarkTap: () {
              ref
                  .read(bookmarkProvider.notifier)
                  .toggle(
                    Bookmark(
                      community: item.community,
                      id: item.id,
                      title: item.title,
                      url: item.url,
                      author: item.author,
                      thumbnailUrl: item.thumbnailUrl,
                      previewText: item.previewText,
                      publishedAt: item.publishedAt,
                      recommendCount: item.recommendCount,
                      commentCount: item.commentCount,
                      viewCount: item.viewCount,
                      savedAt: DateTime.now(),
                    ),
                  );
            },
          ),
        );
      },
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      itemCount: 4,
      physics: const AlwaysScrollableScrollPhysics(),
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.p12),
        child: SkeletonFeedCard(),
      ),
    );
  }
}
