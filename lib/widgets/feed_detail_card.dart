import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/model/url_builder.dart';
import 'package:keek_news/service/video_playback_controller.dart';
import 'package:keek_news/utils/error_report.dart';
import 'package:keek_news/widgets/feed_card_entry.dart';
import 'package:keek_news/widgets/feed_error_card.dart';

/// Dispatches a feed post to the right card for its detail state:
/// loaded → FeedCardEntry, error → FeedErrorCard, otherwise a
/// loading/skeleton FeedCardEntry. Shared by home and bookmarks lists.
class FeedDetailCard extends StatelessWidget {
  const FeedDetailCard({
    required this.post,
    required this.isBookmarked,
    required this.onBookmarkTap,
    required this.onRetryTap,
    this.detail,
    this.detailLoading = false,
    this.appVersion,
    this.controller,
    super.key,
  });

  final FeedItem post;
  final bool isBookmarked;
  final VoidCallback onBookmarkTap;
  final VoidCallback onRetryTap;

  /// Resolved detail value (LoadedPostDetail or ErrorPostDetail), or null
  /// while loading / not yet requested.
  final PostDetail? detail;
  final bool detailLoading;
  final String? appVersion;
  final VideoPlaybackController? controller;

  @override
  Widget build(BuildContext context) {
    if (detail case final LoadedPostDetail loaded) {
      return FeedCardEntry(
        post: post,
        detail: loaded,
        isBookmarked: isBookmarked,
        controller: controller,
        onBookmarkTap: onBookmarkTap,
      );
    }
    if (detail case final ErrorPostDetail err) {
      return FeedErrorCard(
        post: post,
        errorDetail: err,
        onCopyTap: () => _copyErrorReport(context, err),
        onRetryTap: onRetryTap,
      );
    }
    return FeedCardEntry(
      post: post,
      detailLoading: detailLoading,
      isBookmarked: isBookmarked,
      controller: controller,
      onBookmarkTap: onBookmarkTap,
    );
  }

  Future<void> _copyErrorReport(
    BuildContext context,
    ErrorPostDetail err,
  ) async {
    final report = formatErrorReport(
      communityLabel:
          Community.findById(post.community)?.displayName ??
          post.community.name,
      postId: post.id,
      url: UrlBuilder.resolveAbsolute(post.community, post.url),
      title: post.title,
      failure: err.failure,
      appVersion: appVersion,
    );
    await Clipboard.setData(ClipboardData(text: report));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('오류 정보를 복사했어요'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
