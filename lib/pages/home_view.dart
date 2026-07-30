import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keek_news/const/app_spacing.dart';
import 'package:keek_news/model/board_post.dart';
import 'package:keek_news/model/bookmark.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/provider/bookmark_provider.dart';
import 'package:keek_news/provider/merged_feed_provider.dart';
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
    if (index == _tabIndex) return;
    setState(() => _tabIndex = index);
    if (_controller.hasClients) _controller.jumpTo(0);
  }

  List<FeedItem> _filterItems(List<FeedItem> items) {
    final selected = communities[_tabIndex].id;
    return items.where((e) => e.community == selected).toList();
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(mergedFeedProvider);
    final visibleItems = _filterItems(feedState.items);

    return Scaffold(
      appBar: AppBar(
        title: Text(communities[_tabIndex].displayName),
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
          _CommunityTabBar(selectedIndex: _tabIndex, onChanged: _switchTab),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.read(mergedFeedProvider.notifier).fetch(),
              child: _buildBody(feedState, visibleItems),
            ),
          ),
        ],
      ),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: _showScrollTop,
        builder: (context, show, _) => ScrollToTopButton(
          visible: show,
          onTap: () {
            if (_controller.hasClients) {
              _controller.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildBody(MergedFeedState state, List<FeedItem> visibleItems) {
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
        return RepaintBoundary(child: _FeedCard(item: visibleItems[index]));
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

class _CommunityTabBar extends StatelessWidget {
  const _CommunityTabBar({
    required this.selectedIndex,
    required this.onChanged,
  });
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 44,
      color: theme.colorScheme.surfaceContainer,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: communities.length,
        itemBuilder: (context, index) {
          final c = communities[index];
          final selected = index == selectedIndex;
          return GestureDetector(
            onTap: () => onChanged(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    width: 2,
                    color: selected
                        ? Color(c.brandColorArgb)
                        : Colors.transparent,
                  ),
                ),
              ),
              child: Text(
                c.shortName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected
                      ? Color(c.brandColorArgb)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FeedCard extends ConsumerWidget {
  const _FeedCard({required this.item});
  final FeedItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarkProvider);
    final isBookmarked = bookmarks.any(
      (b) => b.community == item.community && b.id == item.id,
    );

    return FeedCardEntry(
      post: BoardPost(
        id: int.tryParse(item.id) ?? 0,
        title: item.title,
        url: item.url,
        author: item.author ?? '',
        date: item.publishedAt?.toIso8601String() ?? '',
        recommendCount: item.recommendCount,
        notRecommendCount: 0,
        commentCount: item.commentCount,
        viewCount: item.viewCount,
        thumbnailUrl: item.thumbnailUrl ?? '',
        community: item.community,
      ),
      isBookmarked: isBookmarked,
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
    );
  }
}
