import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:humoruniv/core/themes/app_spacing.dart';
import 'package:humoruniv/core/widgets/atoms/scroll_to_top_button.dart';
import 'package:humoruniv/core/widgets/molecules/feed_card.dart';
import 'package:humoruniv/core/widgets/states/empty_state_view.dart';
import 'package:humoruniv/core/widgets/states/error_state_view.dart';
import 'package:humoruniv/core/widgets/states/skeleton_feed_card.dart';
import 'package:humoruniv/domain/entities/board_post.dart';
import 'package:humoruniv/domain/entities/feed_item.dart';
import 'package:humoruniv/domain/entities/merged_feed.dart';
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
    final pos = _controller.position.pixels;
    final shouldShow = pos > 600.0;
    if (shouldShow != _showScrollTop) {
      setState(() => _showScrollTop = shouldShow);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(mergedFeedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('통합 유머 피드'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '설정',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(mergedFeedProvider),
        child: feedAsync.when(
          loading: _buildLoading,
          error: (_, __) => _buildError(),
          data: (either) => either.fold(
            (_) => _buildError(),
            _buildFeed,
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView.builder(
      itemCount: 4,
      physics: const AlwaysScrollableScrollPhysics(),
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.p12),
        child: SkeletonFeedCard(),
      ),
    );
  }

  Widget _buildError() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        ErrorStateView(
          message: '게시글을 불러올 수 없습니다.',
          onRetry: () => ref.invalidate(mergedFeedProvider),
        ),
      ],
    );
  }

  Widget _buildFeed(MergedPage page) {
    if (page.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          EmptyStateView(message: '게시글이 없습니다.'),
        ],
      );
    }

    return Stack(
      children: [
        ListView.builder(
          controller: _controller,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: page.items.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.p12),
            child: _MergedCard(item: page.items[index]),
          ),
        ),
        Positioned(
          right: AppSpacing.p16,
          bottom: AppSpacing.p16 + MediaQuery.paddingOf(context).bottom,
          child: ScrollToTopButton(
            visible: _showScrollTop,
            onTap: () {
              if (_controller.hasClients) _controller.jumpTo(0);
              ref.invalidate(mergedFeedProvider);
            },
          ),
        ),
      ],
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
