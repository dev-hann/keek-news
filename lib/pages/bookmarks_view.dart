import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/provider/app_version_provider.dart';
import 'package:keek_news/provider/bookmark_provider.dart';
import 'package:keek_news/provider/feed_video_playback_provider.dart';
import 'package:keek_news/provider/merged_feed_provider.dart';
import 'package:keek_news/service/video_playback_controller.dart';
import 'package:keek_news/widgets/empty_state_view.dart';
import 'package:keek_news/widgets/feed_detail_card.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class BookmarksView extends ConsumerWidget {
  const BookmarksView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarkProvider);
    final details = ref.watch(mergedDetailProvider);
    final videoController = ref.watch(videoPlaybackControllerProvider);
    final appVersion = ref.watch(appVersionProvider).valueOrNull;

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
                final item = FeedItem.fromBookmark(bookmark);
                final av = details[key];
                return FeedDetailCard(
                  post: item,
                  detail: av?.value,
                  detailLoading: av?.isLoading ?? false,
                  isBookmarked: true,
                  controller: videoController,
                  appVersion: appVersion,
                  onBookmarkTap: () => ref
                      .read(bookmarkProvider.notifier)
                      .remove(bookmark.community, bookmark.id),
                  onRetryTap: () => ref
                      .read(mergedDetailProvider.notifier)
                      .retryDetail(key),
                );
              },
            ),
    );
  }
}
