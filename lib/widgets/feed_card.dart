import 'package:flutter/material.dart';
import 'package:keek_news/const/app_elevation.dart';
import 'package:keek_news/const/app_sizes.dart';
import 'package:keek_news/const/app_spacing.dart';
import 'package:keek_news/model/board_post.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/utils/time_ago.dart';
import 'package:keek_news/widgets/action_button.dart';
import 'package:keek_news/widgets/avatar.dart';
import 'package:keek_news/widgets/count_badge.dart';
import 'package:keek_news/widgets/feed_image_carousel.dart';
import 'package:keek_news/widgets/skeleton_box.dart';

class FeedCard extends StatelessWidget {
  const FeedCard({
    required this.post,
    super.key,
    this.detail,
    this.detailLoading = false,
    this.onImageTap,
    this.onCommentsTap,
    this.onCopyTap,
    this.onBookmarkTap,
    this.isBookmarked = false,
  });
  final BoardPost post;
  final PostDetail? detail;
  final bool detailLoading;
  final ValueChanged<int>? onImageTap;
  final VoidCallback? onCommentsTap;
  final VoidCallback? onCopyTap;
  final VoidCallback? onBookmarkTap;
  final bool isBookmarked;

  bool get _hasImages => detail != null && detail!.imageUrls.isNotEmpty;

  List<VideoBlock> get _videoBlocks =>
      detail?.contentBlocks.whereType<VideoBlock>().toList() ?? const [];

  String? get _bodyText {
    final d = detail;
    if (d == null) return null;
    final texts = d.contentBlocks
        .whereType<TextBlock>()
        .map((b) => b.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    return texts.isEmpty ? null : texts.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    // Card surface: a tonal step above the scaffold (surfaceContainer) gives
    // real figure-ground contrast in BOTH light and dark. Light mode adds a
    // hairline elevation; dark mode is tonal-only (DESIGN.md elevation rule).
    // No radius — keeping media full-bleed square (Visual content priority).
    return Material(
      color: colorScheme.surfaceContainer,
      elevation: isDark ? AppElevation.level0 : AppElevation.level1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(textTheme, colorScheme),
          ..._media(),
          _actions(),
          _caption(textTheme, colorScheme),
          if (detail != null && detail!.comments.isNotEmpty)
            _commentPreview(textTheme, colorScheme),
          if (post.date.isNotEmpty) _timestamp(textTheme, colorScheme),
        ],
      ),
    );
  }

  List<Widget> _media() {
    if (detailLoading && !_hasImages && _videoBlocks.isEmpty) {
      return [
        const SkeletonBox(
          width: double.infinity,
          height: AppSizes.feedMediaMaxHeight,
        ),
      ];
    }
    if (_hasImages || _videoBlocks.isNotEmpty) {
      return [
        FeedImageCarousel(
          imageUrls: detail?.imageUrls ?? const [],
          videoBlocks: _videoBlocks,
          onImageTap: onImageTap,
          postId: post.id,
        ),
      ];
    }
    // Text-only posts: no media block. Title + body render in the caption.
    return [];
  }

  Widget _header(TextTheme textTheme, ColorScheme colorScheme) {
    final showBest = post.recommendCount >= 500;
    return Padding(
      padding: AppSpacing.edgeH16V8,
      child: Row(
        children: [
          const Avatar(),
          AppSpacing.sbW12,
          Expanded(
            child: Text(
              post.author,
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showBest) ...[AppSpacing.sbW8, const BestBadge()],
        ],
      ),
    );
  }

  Widget _actions() {
    final showActions = onCopyTap != null || onBookmarkTap != null;
    return Padding(
      padding: AppSpacing.edgeH16V8,
      child: Row(
        children: [
          RecommendBadge(count: post.recommendCount),
          AppSpacing.sbW16,
          CommentBadge(count: post.commentCount),
          AppSpacing.sbW16,
          ViewBadge(count: post.viewCount),
          if (showActions) ...[
            const Spacer(),
            AppSpacing.sbW24,
            ActionButton(
              icon: Icons.link,
              semanticsLabel: '링크 복사',
              onTap: onCopyTap,
            ),
            ActionButton(
              icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              semanticsLabel: isBookmarked ? '저장 취소' : '저장',
              active: isBookmarked,
              onTap: onBookmarkTap,
            ),
          ],
        ],
      ),
    );
  }

  Widget _caption(TextTheme textTheme, ColorScheme colorScheme) {
    final body = _bodyText;
    return Padding(
      padding: AppSpacing.edgeH16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (body != null && body.isNotEmpty) ...[
            AppSpacing.sbH4,
            _ExpandableText(body, maxLines: _hasImages ? 3 : 8),
          ],
        ],
      ),
    );
  }

  Widget _commentPreview(TextTheme textTheme, ColorScheme colorScheme) {
    final first = detail!.comments.first;
    return GestureDetector(
      onTap: onCommentsTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        label: '댓글 미리보기 — 탭하여 모든 댓글 보기',
        button: true,
        child: Padding(
          padding: AppSpacing.edgeH16V8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '댓글 ${detail!.commentCount}개 모두 보기',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              AppSpacing.sbH4,
              RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${first.author} ',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(text: first.content, style: textTheme.labelSmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timestamp(TextTheme textTheme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.p16,
        top: AppSpacing.p4,
        bottom: AppSpacing.p8,
      ),
      child: Text(
        TimeAgo.formatDateString(post.date),
        style: textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ExpandableText extends StatefulWidget {
  const _ExpandableText(this.text, {this.maxLines = 3});
  final String text;
  final int maxLines;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: widget.maxLines,
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflow = painter.didExceedMaxLines;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: style,
              maxLines: _expanded ? null : widget.maxLines,
              overflow: TextOverflow.ellipsis,
            ),
            if (overflow)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _expanded = !_expanded),
                child: Semantics(
                  label: _expanded ? '접기' : '더보기',
                  button: true,
                  child: Container(
                    alignment: Alignment.centerLeft,
                    constraints: const BoxConstraints(
                      minHeight: AppSizes.minTouchTarget,
                      minWidth: AppSizes.minTouchTarget,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _expanded ? '접기' : '더보기',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
