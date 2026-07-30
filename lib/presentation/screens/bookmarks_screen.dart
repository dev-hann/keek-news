import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:happy_news/core/themes/app_spacing.dart';
import 'package:happy_news/core/widgets/molecules/feed_card.dart';
import 'package:happy_news/core/widgets/states/empty_state_view.dart';
import 'package:happy_news/domain/entities/board_post.dart';
import 'package:happy_news/domain/entities/bookmark.dart';
import 'package:happy_news/presentation/providers/bookmark_provider.dart';

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

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
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.p12),
                  child: _BookmarkFeedCard(bookmark: bookmark),
                );
              },
            ),
    );
  }
}

class _BookmarkFeedCard extends ConsumerWidget {
  const _BookmarkFeedCard({required this.bookmark});
  final Bookmark bookmark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FeedCard(
      post: _toBoardPost(bookmark),
      isBookmarked: true,
      onBookmarkTap: () {
        ref
            .read(bookmarkProvider.notifier)
            .remove(bookmark.community, bookmark.id);
      },
      onCopyTap: () async {
        await Clipboard.setData(ClipboardData(text: bookmark.url));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('링크를 복사했어요'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
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
