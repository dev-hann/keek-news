import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/model/url_builder.dart';
import 'package:keek_news/pages/image_viewer_view.dart';
import 'package:keek_news/service/video_playback_controller.dart';
import 'package:keek_news/widgets/comment_tile.dart';
import 'package:keek_news/widgets/feed_card.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class FeedCardEntry extends StatelessWidget {
  const FeedCardEntry({
    required this.post,
    required this.isBookmarked,
    required this.onBookmarkTap,
    this.detail,
    this.detailLoading = false,
    this.controller,
    super.key,
  });

  final FeedItem post;
  final bool isBookmarked;
  final VoidCallback onBookmarkTap;
  final LoadedPostDetail? detail;
  final bool detailLoading;
  final VideoPlaybackController? controller;

  @override
  Widget build(BuildContext context) {
    final hasImages = detail != null && detail!.imageUrls.isNotEmpty;
    final hasComments = detail != null && detail!.comments.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FeedCard(
        post: post,
        detail: detail,
        detailLoading: detailLoading,
        videoController: controller,
        isBookmarked: isBookmarked,
        onImageTap: !hasImages
            ? null
            : (i) => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => ImageViewerView(
                    imageUrls: detail!.imageUrls,
                    initialIndex: i,
                  ),
                  fullscreenDialog: true,
                ),
              ),
        onCommentsTap: !hasComments ? null : () => _showComments(context),
        onCopyTap: () async {
          await Clipboard.setData(
            ClipboardData(
              text: UrlBuilder.resolveAbsolute(post.community, post.url),
            ),
          );
          if (!context.mounted) return;
          // Snackbar stays for now (ScaffoldMessenger is provided by
          // KeekNewsApp builder). Migration to ShadSonner toast deferred —
          // requires toast context plumbing through the widget tree.
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

  void _showComments(BuildContext context) {
    final detail = this.detail;
    if (detail == null) return;
    // Modal bottom sheet stays Material-side; ShadSheet relies on ShadApp
    // root wiring that conflicts with current router setup. Deferred.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '댓글 ${detail.commentCount}개',
                    style: ShadTheme.of(context).textTheme.h4,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
