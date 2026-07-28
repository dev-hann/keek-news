import 'package:humoruniv/domain/entities/community.dart';
import 'package:humoruniv/domain/entities/feed_item.dart';

class FeedItemDto {
  const FeedItemDto({
    required this.community,
    required this.id,
    required this.title,
    required this.url,
    this.author,
    this.publishedAt,
    this.recommendCount = 0,
    this.commentCount = 0,
    this.viewCount = 0,
    this.thumbnailUrl,
    this.previewText,
  });

  final CommunityId community;
  final String id;
  final String title;
  final String url;
  final String? author;
  final DateTime? publishedAt;
  final int recommendCount;
  final int commentCount;
  final int viewCount;
  final String? thumbnailUrl;
  final String? previewText;

  FeedItem toEntity() => FeedItem(
        community: community,
        id: id,
        title: title,
        url: url,
        author: author,
        publishedAt: publishedAt,
        recommendCount: recommendCount,
        commentCount: commentCount,
        viewCount: viewCount,
        thumbnailUrl: thumbnailUrl,
        previewText: previewText,
      );
}
