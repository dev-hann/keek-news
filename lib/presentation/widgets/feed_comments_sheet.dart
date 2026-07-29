import 'package:flutter/material.dart';

import 'package:happy_news/core/themes/app_radius.dart';
import 'package:happy_news/core/themes/app_spacing.dart';
import 'package:happy_news/domain/entities/comment.dart';
import 'package:happy_news/presentation/widgets/comment_tile.dart';

class FeedCommentsSheet extends StatelessWidget {
  const FeedCommentsSheet({
    required this.comments,
    required this.count,
    super.key,
  });
  final List<Comment> comments;
  final int count;

  static const _handleWidth = 36.0;
  static const _handleHeight = 4.0;
  static const _handleAlpha = 0.4;
  static const _dividerAlpha = 0.12;
  static const _separatorAlpha = 0.08;
  static const _sheetHeightRatio = 0.85;

  List<Comment> get _sorted {
    final list = [...comments];
    list.sort((a, b) {
      if (a.isBest != b.isBest) return a.isBest ? -1 : 1;
      return b.recommendCount.compareTo(a.recommendCount);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sorted = _sorted;
    final dividerColor = colorScheme.outline;
    return SafeArea(
      child: Column(
        children: [
          Container(
            width: _handleWidth,
            height: _handleHeight,
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.p8),
            decoration: BoxDecoration(
              color: dividerColor.withValues(alpha: _handleAlpha),
              borderRadius: BorderRadius.circular(_handleHeight / 2),
            ),
          ),
          Padding(
            padding: AppSpacing.edgeH8V4,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: '닫기',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Text(
                  '댓글 $count개',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: dividerColor.withValues(alpha: _dividerAlpha),
          ),
          Expanded(
            child: ListView.separated(
              padding: AppSpacing.edgeH16V8,
              itemCount: sorted.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: dividerColor.withValues(alpha: _separatorAlpha),
              ),
              itemBuilder: (context, index) =>
                  CommentTile(comment: sorted[index]),
            ),
          ),
        ],
      ),
    );
  }
}

void showFeedCommentsSheet(
  BuildContext context,
  List<Comment> comments,
  int count,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => SizedBox(
      height:
          MediaQuery.sizeOf(context).height *
          FeedCommentsSheet._sheetHeightRatio,
      child: FeedCommentsSheet(comments: comments, count: count),
    ),
  );
}
