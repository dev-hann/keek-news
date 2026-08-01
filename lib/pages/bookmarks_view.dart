import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keek_news/model/bookmark.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/provider/bookmark_provider.dart';
import 'package:keek_news/provider/feed_video_playback_provider.dart';
import 'package:keek_news/provider/merged_feed_provider.dart';
import 'package:keek_news/widgets/empty_state_view.dart';
import 'package:keek_news/widgets/feed_card_entry.dart';

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
              icon: Icons.bookmark_border,
            )
          : ListView.builder(
              itemCount: bookmarks.length,
              itemBuilder: (context, i) {
                final bookmark = bookmarks[i];
                final key = (community: bookmark.community, id: bookmark.id);
                final av = details[key];
                if (!details.containsKey(key)) {
                  Future.microtask(
                    () => ref
                        .read(mergedDetailProvider.notifier)
                        .fetchDetail(key),
                  );
                }
                final detail = av?.whenOrNull(
                  data: (either) => either.fold((_) => null, (d) => d),
                );
                return FeedCardEntry(
                  post: _toFeedItem(bookmark),
                  detail: detail,
                  detailLoading: av?.isLoading ?? false,
                  isBookmarked: true,
                  controller: videoController,
                  onBookmarkTap: () {
                    ref
                        .read(bookmarkProvider.notifier)
                        .remove(bookmark.community, bookmark.id);
                  },
                );
              },
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
