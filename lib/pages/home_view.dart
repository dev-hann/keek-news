import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keek_news/model/bookmark.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/provider/app_version_provider.dart';
import 'package:keek_news/provider/bookmark_provider.dart';
import 'package:keek_news/provider/feed_video_playback_provider.dart';
import 'package:keek_news/provider/merged_feed_provider.dart';
import 'package:keek_news/provider/settings_provider.dart';
import 'package:keek_news/service/video_playback_controller.dart';
import 'package:keek_news/widgets/community_tab_bar.dart';
import 'package:keek_news/widgets/empty_state_view.dart';
import 'package:keek_news/widgets/error_state_view.dart';
import 'package:keek_news/widgets/feed_detail_card.dart';
import 'package:keek_news/widgets/loading_indicator.dart';
import 'package:keek_news/widgets/scroll_to_top_button.dart';
import 'package:keek_news/widgets/skeleton_feed_card.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
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
      duration: const Duration(milliseconds: 250),
      curve: Curves.decelerate,
    );
  }

  void _onTopTap() {
    if (_controller.hasClients && _controller.offset > 0) {
      _scrollToTop();
    } else {
      _reloadFeed(silent: true);
    }
  }

  void _onScrollToTopButtonTap() {
    if (_controller.hasClients && _controller.offset > 0) {
      _controller.jumpTo(0);
    }
    _reloadFeed(silent: true);
  }

  List<FeedItem> _filterItems(
    List<FeedItem> items,
    List<Community> visible,
    int tabIndex,
  ) {
    if (tabIndex >= visible.length) return items;
    final selected = visible[tabIndex].id;
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

  Future<void> _reloadFeed({required bool silent}) async {
    // Clear stale detail state (including resolved error cards) so errored
    // posts get a fresh fetch instead of staying pinned as error cards.
    ref.read(mergedDetailProvider.notifier).clear();
    if (silent) {
      await ref.read(mergedFeedProvider.notifier).refresh();
    } else {
      await ref.read(mergedFeedProvider.notifier).fetch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(mergedFeedProvider);
    final bookmarks = ref.watch(bookmarkProvider);
    final details = ref.watch(mergedDetailProvider);
    final videoController = ref.watch(videoPlaybackControllerProvider);
    final appVersion = ref.watch(appVersionProvider).valueOrNull;
    final enabled = ref.watch(settingsProvider);
    final visibleCommunities = communities
        .where((c) => enabled.contains(c.id))
        .toList();
    if (visibleCommunities.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final tabIndex = _tabIndex < visibleCommunities.length ? _tabIndex : 0;
    final visibleItems = _filterItems(
      feedState.items,
      visibleCommunities,
      tabIndex,
    );
    _ensureDetailsLoaded(visibleItems, details);

    final surface = Theme.of(context).colorScheme.surfaceContainer;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _reloadFeed(silent: false),
        child: CustomScrollView(
          controller: _controller,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              title: GestureDetector(
                onTap: _onTopTap,
                behavior: HitTestBehavior.opaque,
                child: Text(visibleCommunities[tabIndex].displayName),
              ),
              actions: [
                IconButton(
                  icon: const Icon(LucideIcons.settings),
                  tooltip: '설정',
                  onPressed: () => context.push('/settings'),
                ),
              ],
              floating: true,
              snap: true,
              backgroundColor: surface,
              elevation: 0,
              scrolledUnderElevation: 0,
            ),
            if (visibleCommunities.length > 1)
              SliverAppBar(
                primary: false,
                automaticallyImplyLeading: false,
                titleSpacing: 0,
                toolbarHeight: 44,
                title: CommunityTabBar(
                  communities: visibleCommunities,
                  selectedIndex: tabIndex,
                  onChanged: _switchTab,
                ),
                floating: true,
                snap: true,
                backgroundColor: surface,
                elevation: 0,
                scrolledUnderElevation: 0,
              ),
            ..._buildSliverBody(
              feedState,
              visibleItems,
              bookmarks,
              details,
              videoController,
              appVersion,
            ),
          ],
        ),
      ),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: _showScrollTop,
        builder: (context, show, _) =>
            ScrollToTopButton(visible: show, onTap: _onScrollToTopButtonTap),
      ),
    );
  }

  List<Widget> _buildSliverBody(
    MergedFeedState state,
    List<FeedItem> visibleItems,
    List<Bookmark> bookmarks,
    MergedDetailMap details,
    VideoPlaybackController videoController,
    String? appVersion,
  ) {
    if (state.isLoading) {
      return [_sliverSkeleton()];
    }
    if (state.error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorStateView(
            message: state.error!,
            onRetry: () => _reloadFeed(silent: false),
          ),
        ),
      ];
    }
    if (visibleItems.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyStateView(message: '게시글이 없습니다.'),
        ),
      ];
    }

    final extra = (state.hasMore || state.isLoadingMore) ? 1 : 0;

    return [
      SliverList.builder(
        itemCount: visibleItems.length + extra,
        itemBuilder: (context, index) {
          if (index == visibleItems.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: LoadingIndicator(),
            );
          }
          final item = visibleItems[index];
          final key = (community: item.community, id: item.id);
          final av = details[key];
          return RepaintBoundary(
            child: FeedDetailCard(
              post: item,
              detail: av?.value,
              detailLoading: av?.isLoading ?? false,
              isBookmarked: bookmarks.any(
                (b) => b.community == item.community && b.id == item.id,
              ),
              controller: videoController,
              appVersion: appVersion,
              onBookmarkTap: () => _toggleBookmark(item),
              onRetryTap: () =>
                  ref.read(mergedDetailProvider.notifier).retryDetail(key),
            ),
          );
        },
      ),
    ];
  }

  void _toggleBookmark(FeedItem item) {
    ref
        .read(bookmarkProvider.notifier)
        .toggle(Bookmark.fromFeedItem(item, savedAt: DateTime.now()));
  }

  Widget _sliverSkeleton() {
    return SliverList.builder(
      itemCount: 4,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: SkeletonFeedCard(),
      ),
    );
  }
}
