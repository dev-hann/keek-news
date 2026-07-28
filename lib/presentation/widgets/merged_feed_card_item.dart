import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:humoruniv/core/widgets/molecules/feed_card.dart';
import 'package:humoruniv/core/widgets/states/skeleton_feed_card.dart';
import 'package:humoruniv/domain/entities/board_post.dart';
import 'package:humoruniv/domain/entities/feed_item.dart';
import 'package:humoruniv/presentation/providers/merged_feed_provider.dart';
import 'package:humoruniv/presentation/screens/image_viewer_screen.dart';
import 'package:humoruniv/presentation/widgets/community_badge.dart';
import 'package:humoruniv/presentation/widgets/feed_comments_sheet.dart';

extension FeedItemToBoardPost on FeedItem {
  BoardPost toBoardPost() => BoardPost(
        id: int.tryParse(id) ?? 0,
        title: title,
        url: url,
        author: author ?? '',
        date: publishedAt?.toIso8601String() ?? '',
        recommendCount: recommendCount,
        notRecommendCount: 0,
        commentCount: commentCount,
        viewCount: viewCount,
        thumbnailUrl: thumbnailUrl ?? '',
        previewText: previewText,
        community: community,
      );
}

class MergedFeedCardItem extends ConsumerStatefulWidget {
  const MergedFeedCardItem({required this.item, super.key});
  final FeedItem item;

  @override
  ConsumerState<MergedFeedCardItem> createState() => _MergedFeedCardItemState();
}

class _MergedFeedCardItemState extends ConsumerState<MergedFeedCardItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final item = widget.item;
    final asyncDetail = ref.watch(
      mergedDetailProvider((community: item.community, id: item.id)),
    );
    final detail = asyncDetail.whenOrNull(
      data: (either) => either.fold((_) => null, (d) => d),
    );
    final hasImages = detail != null && detail.imageUrls.isNotEmpty;
    final hasComments = detail != null && detail.comments.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: CommunityBadge(community: item.community),
          ),
        ),
        FeedCard(
          post: item.toBoardPost(),
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
              : () => showFeedCommentsSheet(
                    context,
                    detail.comments,
                    detail.commentCount,
                  ),
        ),
      ],
    );
  }
}

Widget mergedFeedCardSkeleton() => const SkeletonFeedCard();
