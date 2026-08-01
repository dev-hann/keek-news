import 'package:flutter/material.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/service/video_playback_controller.dart';
import 'package:keek_news/utils/time_ago.dart';
import 'package:keek_news/widgets/action_button.dart';
import 'package:keek_news/widgets/avatar.dart';
import 'package:keek_news/widgets/count_badge.dart';
import 'package:keek_news/widgets/feed_image_carousel.dart';
import 'package:keek_news/widgets/skeleton_box.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
    this.videoController,
  });
  final FeedItem post;
  final LoadedPostDetail? detail;
  final bool detailLoading;
  final ValueChanged<int>? onImageTap;
  final VoidCallback? onCommentsTap;
  final VoidCallback? onCopyTap;
  final VoidCallback? onBookmarkTap;
  final bool isBookmarked;
  final VideoPlaybackController? videoController;

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
    final theme = ShadTheme.of(context);
    final mTheme = Theme.of(context);
    return ShadCard(
      backgroundColor: mTheme.colorScheme.surfaceContainer,
      padding: EdgeInsets.zero,
      border: ShadBorder.all(color: theme.colorScheme.border, width: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(theme),
          ..._media(),
          _actions(),
          _caption(theme, mTheme),
          if (detail != null && detail!.comments.isNotEmpty)
            _commentPreview(theme, mTheme),
          if (post.publishedAt != null) _timestamp(theme, mTheme),
        ],
      ),
    );
  }

  List<Widget> _media() {
    if (detailLoading && !_hasImages && _videoBlocks.isEmpty) {
      return [const SkeletonBox(width: double.infinity, height: 600)];
    }
    if (_hasImages || _videoBlocks.isNotEmpty) {
      return [
        FeedImageCarousel(
          imageUrls: detail?.imageUrls ?? const [],
          videoBlocks: _videoBlocks,
          onImageTap: onImageTap,
          postId: int.tryParse(post.id) ?? 0,
          videoController: videoController,
        ),
      ];
    }
    return [];
  }

  Widget _header(ShadThemeData theme) {
    final showBest = post.recommendCount >= 500;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Avatar(),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              post.author ?? '',
              style: theme.textTheme.p.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showBest) ...[const SizedBox(width: 8), const BestBadge()],
        ],
      ),
    );
  }

  Widget _actions() {
    final showActions = onCopyTap != null || onBookmarkTap != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          RecommendBadge(count: post.recommendCount),
          const SizedBox(width: 16),
          CommentBadge(
            count: post.commentCount != 0
                ? post.commentCount
                : (detail?.commentCount ?? 0),
          ),
          const SizedBox(width: 16),
          ViewBadge(count: post.viewCount),
          if (showActions) ...[
            const Spacer(),
            const SizedBox(width: 24),
            ActionButton(
              icon: LucideIcons.link,
              semanticsLabel: '링크 복사',
              onTap: onCopyTap,
            ),
            ActionButton(
              icon: isBookmarked
                  ? LucideIcons.bookmarkCheck
                  : LucideIcons.bookmark,
              semanticsLabel: isBookmarked ? '저장 취소' : '저장',
              active: isBookmarked,
              onTap: onBookmarkTap,
            ),
          ],
        ],
      ),
    );
  }

  Widget _caption(ShadThemeData theme, ThemeData mTheme) {
    final body = _bodyText;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.title,
            style: mTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.foreground,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (body != null && body.isNotEmpty) ...[
            const SizedBox(height: 4),
            _ExpandableText(body, maxLines: _hasImages ? 3 : 8),
          ],
        ],
      ),
    );
  }

  Widget _commentPreview(ShadThemeData theme, ThemeData mTheme) {
    final first = detail!.comments.first;
    return GestureDetector(
      onTap: onCommentsTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        label: '댓글 미리보기 — 탭하여 모든 댓글 보기',
        button: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '댓글 ${detail!.commentCount}개 모두 보기',
                style: theme.textTheme.small.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 4),
              RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${first.author} ',
                      style: theme.textTheme.small.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(text: first.content, style: theme.textTheme.small),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timestamp(ShadThemeData theme, ThemeData mTheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 4, bottom: 8),
      child: Text(
        TimeAgo.format(post.publishedAt!),
        style: theme.textTheme.small.copyWith(
          color: theme.colorScheme.mutedForeground,
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
    final theme = ShadTheme.of(context);
    final mTheme = Theme.of(context);
    final style = mTheme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.mutedForeground,
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
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
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
                      minHeight: 44,
                      minWidth: 44,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _expanded ? '접기' : '더보기',
                        style: mTheme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
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
