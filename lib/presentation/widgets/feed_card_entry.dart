import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:happy_news/core/themes/app_spacing.dart';
import 'package:happy_news/core/widgets/molecules/feed_card.dart';
import 'package:happy_news/domain/entities/board_post.dart';
import 'package:happy_news/domain/entities/post_detail.dart';
import 'package:happy_news/presentation/providers/merged_feed_provider.dart';
import 'package:happy_news/presentation/screens/image_viewer_screen.dart';

class FeedCardEntry extends ConsumerWidget {
  const FeedCardEntry({
    required this.post,
    required this.isBookmarked,
    required this.onBookmarkTap,
    super.key,
  });

  final BoardPost post;
  final bool isBookmarked;
  final VoidCallback onBookmarkTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetail = ref.watch(
      mergedDetailProvider((community: post.community, id: '${post.id}')),
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
        onCopyTap: () async {
          await Clipboard.setData(ClipboardData(text: post.url));
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
