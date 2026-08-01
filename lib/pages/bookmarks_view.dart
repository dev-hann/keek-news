import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keek_news/model/bookmark.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/model/url_builder.dart';
import 'package:keek_news/provider/bookmark_provider.dart';
import 'package:keek_news/provider/feed_video_playback_provider.dart';
import 'package:keek_news/provider/merged_feed_provider.dart';
import 'package:keek_news/service/video_playback_controller.dart';
import 'package:keek_news/utils/error_report.dart';
import 'package:keek_news/widgets/empty_state_view.dart';
import 'package:keek_news/widgets/feed_card_entry.dart';
import 'package:keek_news/widgets/feed_error_card.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class BookmarksView extends ConsumerWidget {
  const BookmarksView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarkProvider);
    final details = ref.watch(mergedDetailProvider);
    final videoController = ref.watch(videoPlaybackControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('저장함')),
      body: bookmarks.isEmpty
          ? const EmptyStateView(
              title: '저장한 게시물이 없어요',
              subtitle: '좋아하는 글을 북마크해 보세요',
              icon: LucideIcons.bookmark,
            )
          : ListView.builder(
              itemCount: bookmarks.length,
              itemBuilder: (context, i) {
                final bookmark = bookmarks[i];
                final key = (community: bookmark.community, id: bookmark.id);
                if (!details.containsKey(key)) {
                  Future.microtask(
                    () => ref
                        .read(mergedDetailProvider.notifier)
                        .fetchDetail(key),
                  );
                }
                final av = details[key];
                return _buildCard(context, bookmark, av, videoController, ref);
              },
            ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    Bookmark bookmark,
    AsyncValue<PostDetail>? av,
    VideoPlaybackController videoController,
    WidgetRef ref,
  ) {
    final item = _toFeedItem(bookmark);
    if (av?.value case final LoadedPostDetail loaded) {
      return FeedCardEntry(
        post: item,
        detail: loaded,
        isBookmarked: true,
        controller: videoController,
        onBookmarkTap: () => ref
            .read(bookmarkProvider.notifier)
            .remove(bookmark.community, bookmark.id),
      );
    }
    if (av?.value case final ErrorPostDetail err) {
      return FeedErrorCard(
        post: item,
        errorDetail: err,
        onCopyTap: () => _copyErrorReport(context, item, err),
      );
    }
    return FeedCardEntry(
      post: item,
      detailLoading: av?.isLoading ?? false,
      isBookmarked: true,
      controller: videoController,
      onBookmarkTap: () => ref
          .read(bookmarkProvider.notifier)
          .remove(bookmark.community, bookmark.id),
    );
  }

  Future<void> _copyErrorReport(
    BuildContext context,
    FeedItem item,
    ErrorPostDetail err,
  ) async {
    final report = formatErrorReport(
      communityLabel:
          Community.findById(item.community)?.displayName ??
          item.community.name,
      postId: item.id,
      url: UrlBuilder.resolveAbsolute(item.community, item.url),
      title: item.title,
      failure: err.failure,
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

  FeedItem _toFeedItem(Bookmark b) {
    return FeedItem(
      community: b.community,
      id: b.id,
      title: b.title,
      url: b.url,
      author: b.author,
      publishedAt: b.publishedAt,
      recommendCount: b.recommendCount,
      commentCount: b.commentCount,
      viewCount: b.viewCount,
      thumbnailUrl: b.thumbnailUrl,
      previewText: b.previewText,
    );
  }
}
