import 'package:flutter/material.dart';

import 'package:happy_news/core/themes/app_radius.dart';
import 'package:happy_news/core/themes/app_spacing.dart';
import 'package:happy_news/domain/entities/comment.dart';
import 'package:happy_news/presentation/widgets/content_block_view.dart';

class CommentTile extends StatelessWidget {
  const CommentTile({required this.comment, super.key});
  final Comment comment;

  @override
  Widget build(BuildContext context) {
    final allImageUrls = comment.imageUrls;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.p12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (comment.isBest)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.p6,
                vertical: AppSpacing.p2,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: AppRadius.borderRadiusSm,
              ),
              child: Text(
                'BEST',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          Row(
            children: [
              Text(
                comment.author,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              AppSpacing.sbW8,
              Icon(
                Icons.thumb_up,
                size: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
              Text(
                '${comment.recommendCount}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          AppSpacing.sbH4,
          Text(comment.content, style: Theme.of(context).textTheme.bodyMedium),
          ...comment.mediaBlocks.map(
            (block) =>
                ContentBlockView(block: block, allImageUrls: allImageUrls),
          ),
          if (comment.replies.isNotEmpty)
            ...comment.replies.map(
              (reply) => Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.p16,
                  top: AppSpacing.p8,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                        width: 2,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.only(left: AppSpacing.p8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            reply.author,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          AppSpacing.sbW8,
                          Text(
                            '${reply.recommendCount}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                      AppSpacing.sbH4,
                      Text(
                        reply.content,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      ...reply.mediaBlocks.map(
                        (block) => ContentBlockView(
                          block: block,
                          allImageUrls: reply.imageUrls,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
