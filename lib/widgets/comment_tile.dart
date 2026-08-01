import 'package:flutter/material.dart';
import 'package:keek_news/const/app_radius.dart';
import 'package:keek_news/const/app_spacing.dart';
import 'package:keek_news/model/comment.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/pages/comment_video_viewer.dart';
import 'package:keek_news/pages/image_viewer_view.dart';
import 'package:keek_news/utils/time_ago.dart';
import 'package:keek_news/widgets/retryable_network_image.dart';
import 'package:keek_news/widgets/video_thumbnail.dart';

class CommentTile extends StatelessWidget {
  const CommentTile({required this.comment, this.depth = 0, super.key});

  final Comment comment;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: depth * AppSpacing.p16,
        top: AppSpacing.p8,
        bottom: AppSpacing.p8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            comment: comment,
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
          if (comment.content.isNotEmpty) ...[
            AppSpacing.sbH4,
            Text(
              comment.content,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ],
          if (comment.mediaBlocks.isNotEmpty) ...[
            AppSpacing.sbH8,
            _MediaRow(comment: comment),
          ],
          for (final reply in comment.replies)
            CommentTile(comment: reply, depth: depth + 1),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.comment,
    required this.textTheme,
    required this.colorScheme,
  });

  final Comment comment;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final metaStyle = textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    return Row(
      children: [
        if (comment.isBest) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.p6,
              vertical: AppSpacing.p2,
            ),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: AppRadius.borderRadiusSm,
            ),
            child: Text(
              '베스트',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          AppSpacing.sbW8,
        ],
        Flexible(
          child: Text(
            comment.author,
            style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (comment.recommendCount > 0) ...[
          AppSpacing.sbW8,
          Icon(
            Icons.thumb_up_outlined,
            size: 13,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 2),
          Text('${comment.recommendCount}', style: metaStyle),
        ],
        const Spacer(),
        Text(TimeAgo.format(comment.date), style: metaStyle),
      ],
    );
  }
}

class _MediaRow extends StatelessWidget {
  const _MediaRow({required this.comment});
  final Comment comment;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.p8,
      runSpacing: AppSpacing.p8,
      children: _buildChildren(context),
    );
  }

  List<Widget> _buildChildren(BuildContext context) {
    final imageUrls = comment.imageUrls;
    final children = <Widget>[];
    var imageIndex = 0;
    for (final block in comment.mediaBlocks) {
      if (block is ImageBlock) {
        final idx = imageIndex < imageUrls.length ? imageIndex : 0;
        imageIndex++;
        children.add(
          GestureDetector(
            onTap: () => _openImageViewer(context, imageUrls, idx),
            child: _MediaBox(
              child: RetryableNetworkImage(
                imageUrl: block.url,
                fit: BoxFit.cover,
                width: 80,
                height: 80,
              ),
            ),
          ),
        );
      } else if (block is VideoBlock) {
        children.add(
          GestureDetector(
            onTap: () => _openVideoViewer(context, block),
            child: _MediaBox(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VideoThumbnail(videoUrl: block.url),
                  const Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white70,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    return children;
  }

  void _openImageViewer(BuildContext context, List<String> urls, int index) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ImageViewerView(imageUrls: urls, initialIndex: index),
        fullscreenDialog: true,
      ),
    );
  }

  void _openVideoViewer(BuildContext context, VideoBlock block) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CommentVideoViewer(block: block),
        fullscreenDialog: true,
      ),
    );
  }
}

class _MediaBox extends StatelessWidget {
  const _MediaBox({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.borderRadiusMd,
      child: SizedBox(width: 80, height: 80, child: child),
    );
  }
}
