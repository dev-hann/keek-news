import 'package:flutter/material.dart';
import 'package:keek_news/model/comment.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/pages/comment_video_viewer_view.dart';
import 'package:keek_news/pages/image_viewer_view.dart';
import 'package:keek_news/utils/time_ago.dart';
import 'package:keek_news/widgets/retryable_network_image.dart';
import 'package:keek_news/widgets/video_thumbnail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class CommentTile extends StatelessWidget {
  const CommentTile({required this.comment, this.depth = 0, super.key});

  final Comment comment;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final mTheme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(left: depth * 16.0, top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(comment: comment, theme: theme, mTheme: mTheme),
          if (comment.content.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              comment.content,
              style: mTheme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.foreground,
              ),
            ),
          ],
          if (comment.mediaBlocks.isNotEmpty) ...[
            const SizedBox(height: 8),
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
    required this.theme,
    required this.mTheme,
  });

  final Comment comment;
  final ShadThemeData theme;
  final ThemeData mTheme;

  @override
  Widget build(BuildContext context) {
    final metaStyle = theme.textTheme.small.copyWith(
      color: theme.colorScheme.mutedForeground,
    );
    return Row(
      children: [
        if (comment.isBest) ...[
          ShadBadge(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.primaryForeground,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
            child: Text(
              '베스트',
              style: theme.textTheme.small.copyWith(
                color: theme.colorScheme.primaryForeground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            comment.author,
            style: mTheme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (comment.recommendCount > 0) ...[
          const SizedBox(width: 8),
          Icon(
            LucideIcons.thumbsUp,
            size: 13,
            color: theme.colorScheme.mutedForeground,
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
    return Wrap(spacing: 8, runSpacing: 8, children: _buildChildren(context));
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
                      LucideIcons.circlePlay,
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
        builder: (_) => CommentVideoViewerView(block: block),
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
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      child: SizedBox(width: 80, height: 80, child: child),
    );
  }
}
