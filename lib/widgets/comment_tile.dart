import 'package:flutter/material.dart';
import 'package:keek_news/const/app_radius.dart';
import 'package:keek_news/const/app_spacing.dart';
import 'package:keek_news/model/comment.dart';
import 'package:keek_news/pages/image_viewer_view.dart';
import 'package:keek_news/utils/time_ago.dart';
import 'package:keek_news/widgets/retryable_network_image.dart';

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
          if (comment.imageUrls.isNotEmpty) ...[
            AppSpacing.sbH8,
            _ImageRow(comment: comment),
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

class _ImageRow extends StatelessWidget {
  const _ImageRow({required this.comment});
  final Comment comment;

  @override
  Widget build(BuildContext context) {
    final urls = comment.imageUrls;
    return Wrap(
      spacing: AppSpacing.p8,
      runSpacing: AppSpacing.p8,
      children: [
        for (var i = 0; i < urls.length; i++)
          GestureDetector(
            onTap: () => _openViewer(context, urls, i),
            child: ClipRRect(
              borderRadius: AppRadius.borderRadiusMd,
              child: SizedBox(
                width: 80,
                height: 80,
                child: RetryableNetworkImage(
                  imageUrl: urls[i],
                  fit: BoxFit.cover,
                  width: 80,
                  height: 80,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openViewer(BuildContext context, List<String> urls, int index) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ImageViewerView(imageUrls: urls, initialIndex: index),
        fullscreenDialog: true,
      ),
    );
  }
}
