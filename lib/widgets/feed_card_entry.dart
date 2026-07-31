import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keek_news/const/app_spacing.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/pages/image_viewer_view.dart';
import 'package:keek_news/provider/merged_feed_provider.dart';
import 'package:keek_news/utils/url_builder.dart';
import 'package:keek_news/widgets/comment_tile.dart';
import 'package:keek_news/widgets/feed_card.dart';

class FeedCardEntry extends ConsumerWidget {
  const FeedCardEntry({
    required this.post,
    required this.isBookmarked,
    required this.onBookmarkTap,
    super.key,
  });

  final FeedItem post;
  final bool isBookmarked;
  final VoidCallback onBookmarkTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetail = ref.watch(
      mergedDetailProvider((community: post.community, id: post.id)),
    );

    final detail = asyncDetail.whenOrNull(
      data: (either) => either.fold((_) => null, (d) => d),
    );
    final hasImages = detail != null && detail.imageUrls.isNotEmpty;
    final hasComments = detail != null && detail.comments.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.p12),
      child: FeedCard(
        post: post,
        detail: detail,
        detailLoading: asyncDetail.isLoading,
        isBookmarked: isBookmarked,
        onImageTap: !hasImages
            ? null
            : (i) => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => ImageViewerView(
                    imageUrls: detail.imageUrls,
                    initialIndex: i,
                  ),
                  fullscreenDialog: true,
                ),
              ),
        onCommentsTap: !hasComments
            ? null
            : () => _showComments(context, detail),
        onCopyTap: () async {
          await Clipboard.setData(
            ClipboardData(
              text: UrlBuilder.resolveAbsolute(post.community, post.url),
            ),
          );
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('링크를 복사했어요'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        onBookmarkTap: onBookmarkTap,
      ),
    );
  }

  void _showComments(BuildContext context, PostDetail detail) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.only(
            top: AppSpacing.p8,
            bottom: AppSpacing.p16,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.p16,
                  vertical: AppSpacing.p8,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '댓글 ${detail.commentCount}개',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.p16,
                  ),
                  itemCount: detail.comments.length,
                  itemBuilder: (_, i) =>
                      CommentTile(comment: detail.comments[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
