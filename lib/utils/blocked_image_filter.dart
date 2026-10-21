import 'package:keek_news/model/comment.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/post_detail.dart';

/// Removes images whose canonical URL is in [blocked] from a post detail
/// (body blocks, detail imageUrls, and comment media recursively).
/// Non-loaded detail states pass through untouched; an empty blocklist
/// returns [detail] as-is.
PostDetail? filterBlockedPostDetail(PostDetail? detail, Set<String> blocked) {
  if (detail is! LoadedPostDetail || blocked.isEmpty) return detail;

  final contentBlocks = <ContentBlock>[
    for (final b in detail.contentBlocks)
      if (!_isBlockedImage(b, blocked)) b,
  ];
  final imageUrls = detail.imageUrls
      .where((url) => !blocked.contains(url))
      .toList();
  final comments = [
    for (final c in detail.comments) _filterComment(c, blocked),
  ];

  return LoadedPostDetail(
    id: detail.id,
    community: detail.community,
    title: detail.title,
    author: detail.author,
    date: detail.date,
    contentBlocks: contentBlocks,
    imageUrls: imageUrls,
    recommendCount: detail.recommendCount,
    notRecommendCount: detail.notRecommendCount,
    viewCount: detail.viewCount,
    commentCount: detail.commentCount,
    comments: comments,
  );
}

bool _isBlockedImage(ContentBlock block, Set<String> blocked) =>
    block is ImageBlock && blocked.contains(block.url);

Comment _filterComment(Comment comment, Set<String> blocked) {
  final mediaBlocks = <ContentBlock>[
    for (final b in comment.mediaBlocks)
      if (!_isBlockedImage(b, blocked)) b,
  ];
  final replies = [for (final r in comment.replies) _filterComment(r, blocked)];
  return Comment(
    id: comment.id,
    author: comment.author,
    content: comment.content,
    date: comment.date,
    recommendCount: comment.recommendCount,
    isBest: comment.isBest,
    replies: replies,
    mediaBlocks: mediaBlocks,
  );
}
