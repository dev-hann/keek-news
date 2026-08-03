import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keek_news/model/bookmark.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/model/url_builder.dart';
import 'package:keek_news/provider/bookmark_provider.dart';
import 'package:keek_news/provider/feed_video_playback_provider.dart';
import 'package:keek_news/provider/merged_feed_provider.dart';
import 'package:keek_news/provider/settings_provider.dart';
import 'package:keek_news/service/video_playback_controller.dart';
import 'package:keek_news/utils/error_report.dart';
import 'package:keek_news/widgets/community_tab_bar.dart';
import 'package:keek_news/widgets/empty_state_view.dart';
import 'package:keek_news/widgets/error_state_view.dart';
import 'package:keek_news/widgets/feed_card_entry.dart';
import 'package:keek_news/widgets/feed_error_card.dart';
import 'package:keek_news/widgets/loading_indicator.dart';
import 'package:keek_news/widgets/scroll_to_top_button.dart';
import 'package:keek_news/widgets/skeleton_feed_card.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = info.version);
    });
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

  List<FeedItem> _filterItems(List<FeedItem> items, List<Community> visible) {
    if (_tabIndex >= visible.length) return items;
    final selected = visible[_tabIndex].id;
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

  void _toggleBookmark(FeedItem item) {
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
  }

  Future<void> _copyErrorReport(FeedItem item, ErrorPostDetail err) async {
    final report = formatErrorReport(
      communityLabel:
          Community.findById(item.community)?.displayName ??
          item.community.name,
      postId: item.id,
      url: UrlBuilder.resolveAbsolute(item.community, item.url),
      title: item.title,
      failure: err.failure,
      appVersion: _appVersion,
    );
    await Clipboard.setData(ClipboardData(text: report));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('오류 정보를 복사했어요'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(mergedFeedProvider);
    final bookmarks = ref.watch(bookmarkProvider);
    final details = ref.watch(mergedDetailProvider);
    final videoController = ref.watch(videoPlaybackControllerProvider);
    final enabled = ref.watch(settingsProvider);
    final visibleCommunities = communities
        .where((c) => enabled.contains(c.id))
        .toList();
    if (visibleCommunities.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_tabIndex >= visibleCommunities.length) _tabIndex = 0;
    final visibleItems = _filterItems(feedState.items, visibleCommunities);
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
                child: Text(visibleCommunities[_tabIndex].displayName),
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
                  selectedIndex: _tabIndex,
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
            ),
          ],
        ),
      ),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: _showScrollTop,
        builder: (context, show, _) =>
            ScrollToTopButton(visible: show, onTap: _scrollToTop),
      ),
    );
  }

  List<Widget> _buildSliverBody(
    MergedFeedState state,
    List<FeedItem> visibleItems,
    List<Bookmark> bookmarks,
    MergedDetailMap details,
    VideoPlaybackController videoController,
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
          final av = details[(community: item.community, id: item.id)];
          return RepaintBoundary(
            child: _buildCardFor(item, av, bookmarks, videoController),
          );
        },
      ),
    ];
  }

  Widget _buildCardFor(
    FeedItem item,
    AsyncValue<PostDetail>? av,
    List<Bookmark> bookmarks,
    VideoPlaybackController videoController,
  ) {
    final bookmarked = bookmarks.any(
      (b) => b.community == item.community && b.id == item.id,
    );
    if (av?.value case final LoadedPostDetail loaded) {
      return FeedCardEntry(
        post: item,
        detail: loaded,
        isBookmarked: bookmarked,
        controller: videoController,
        onBookmarkTap: () => _toggleBookmark(item),
      );
    }
    if (av?.value case final ErrorPostDetail err) {
      return FeedErrorCard(
        post: item,
        errorDetail: err,
        onCopyTap: () => _copyErrorReport(item, err),
        onRetryTap: () => ref.read(mergedDetailProvider.notifier).retryDetail((
          community: item.community,
          id: item.id,
        )),
      );
    }
    // Loading or detail not yet requested: render the list-level card; the
    // media area shows a skeleton while loading.
    return FeedCardEntry(
      post: item,
      detailLoading: av?.isLoading ?? false,
      isBookmarked: bookmarked,
      controller: videoController,
      onBookmarkTap: () => _toggleBookmark(item),
    );
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
