import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keek_news/model/board_post.dart';
import 'package:keek_news/model/bookmark.dart';
import 'package:keek_news/provider/bookmark_provider.dart';
import 'package:keek_news/widgets/empty_state_view.dart';
import 'package:keek_news/widgets/feed_card_entry.dart';

class BookmarksView extends ConsumerWidget {
  const BookmarksView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarkProvider);

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
                return FeedCardEntry(
                  post: _toBoardPost(bookmark),
                  isBookmarked: true,
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

  BoardPost _toBoardPost(Bookmark b) {
    return BoardPost(
      id: int.tryParse(b.id) ?? 0,
      title: b.title,
      url: b.url,
      author: b.author ?? '',
      date: b.publishedAt?.toIso8601String() ?? '',
      recommendCount: b.recommendCount,
      notRecommendCount: 0,
      commentCount: b.commentCount,
      viewCount: b.viewCount,
      thumbnailUrl: b.thumbnailUrl ?? '',
      previewText: b.previewText,
      community: b.community,
    );
  }
}
