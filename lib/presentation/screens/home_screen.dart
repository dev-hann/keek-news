import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:humoruniv/core/themes/app_spacing.dart';
import 'package:humoruniv/core/widgets/atoms/loading_indicator.dart';
import 'package:humoruniv/core/widgets/atoms/scroll_to_top_button.dart';
import 'package:humoruniv/core/widgets/molecules/feed_card.dart';
import 'package:humoruniv/core/widgets/states/empty_state_view.dart';
import 'package:humoruniv/core/widgets/states/error_state_view.dart';
import 'package:humoruniv/core/widgets/states/skeleton_feed_card.dart';
import 'package:humoruniv/domain/entities/board_post.dart';
import 'package:humoruniv/domain/entities/comment.dart';
import 'package:humoruniv/domain/entities/community.dart';
import 'package:humoruniv/domain/entities/feed_item.dart';
import 'package:humoruniv/domain/entities/post_detail.dart';
import 'package:humoruniv/presentation/providers/merged_feed_provider.dart';
import 'package:humoruniv/presentation/screens/image_viewer_screen.dart';
import 'package:humoruniv/presentation/widgets/community_badge.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _controller = ScrollController();
  bool _showScrollTop = false;
  CommunityId? _filter; // null = 전체

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    if (pos.pixels >= pos.maxScrollExtent * 0.85) {
      ref.read(mergedFeedProvider.notifier).fetchNextPage();
    }
    final shouldShow = pos.pixels > 600;
    if (shouldShow != _showScrollTop) {
      setState(() => _showScrollTop = shouldShow);
    }
  }

  List<FeedItem> _applyFilter(List<FeedItem> items) {
    if (_filter == null) return items;
    return items.where((e) => e.community == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(mergedFeedProvider);
    final visibleItems = _applyFilter(feedState.items);

    return DefaultTabController(
      length: communities.length + 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('통합 유머 피드'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: '설정',
              onPressed: () => context.push('/settings'),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            onTap: (i) {
              setState(() {
                _filter = i == 0 ? null : communities[i - 1].id;
                if (_controller.hasClients) _controller.jumpTo(0);
              });
            },
            tabs: [
              const Tab(text: '전체'),
              ...communities.map((c) => Tab(text: c.shortName)),
            ],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: () async => ref.read(mergedFeedProvider.notifier).fetch(),
          child: _buildBody(feedState, visibleItems),
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

    final extra = (state.hasMore || state.isLoadingMore) && _filter == null
        ? 1
        : 0;
    final hasBanner = state.failedSources.isNotEmpty && _filter == null;

    return Stack(
      children: [
        ListView.builder(
          controller: _controller,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: visibleItems.length + (hasBanner ? 1 : 0) + extra,
          itemBuilder: (context, index) {
            if (hasBanner && index == 0) {
              return _PartialFailureBanner(failed: state.failedSources);
            }
            final itemIndex = hasBanner ? index - 1 : index;
            if (itemIndex == visibleItems.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: LoadingIndicator(),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.p12),
              child: _MergedCard(item: visibleItems[itemIndex]),
            );
          },
        ),
        Positioned(
          right: AppSpacing.p16,
          bottom: AppSpacing.p16 + MediaQuery.paddingOf(context).bottom,
          child: ScrollToTopButton(
            visible: _showScrollTop,
            onTap: () {
              if (_controller.hasClients) _controller.jumpTo(0);
              ref.read(mergedFeedProvider.notifier).fetch();
            },
          ),
        ),
      ],
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

class _PartialFailureBanner extends StatelessWidget {
  const _PartialFailureBanner({required this.failed});
  final Set<CommunityId> failed;

  @override
  Widget build(BuildContext context) {
    final names = failed
        .map((id) => Community.findById(id)?.shortName ?? id.name)
        .join(', ');

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.p12,
        vertical: AppSpacing.p4,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$names 커뮤니티 일시적 오류',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MergedCard extends ConsumerWidget {
  const _MergedCard({required this.item});
  final FeedItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetail = ref.watch(
      mergedDetailProvider((community: item.community, id: item.id)),
    );
    final detail = asyncDetail.whenOrNull(
      data: (either) => either.fold((_) => null, (d) => d),
    );
    final hasImages = detail != null && detail.imageUrls.isNotEmpty;
    final hasComments = detail != null && detail.comments.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 4),
          child: CommunityBadge(community: item.community),
        ),
        FeedCard(
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
            previewText: item.previewText,
            community: item.community,
          ),
          detail: detail,
          detailLoading: asyncDetail.isLoading,
          onImageTap: !hasImages
              ? null
              : (i) => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => ImageViewerScreen(
                      imageUrls: detail.imageUrls,
                      initialIndex: i,
                    ),
                    fullscreenDialog: true,
                  ),
                ),
          onCommentsTap: !hasComments
              ? null
              : () => _showComments(context, detail),
        ),
      ],
    );
  }

  void _showComments(BuildContext context, PostDetail detail) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: detail.comments.length,
          itemBuilder: (_, i) => ListTile(
            title: Text(detail.comments[i].author),
            subtitle: Text(detail.comments[i].content),
          ),
        ),
      ),
    );
  }
}
