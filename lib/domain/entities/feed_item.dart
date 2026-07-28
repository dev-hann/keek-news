import 'package:humoruniv/domain/entities/community.dart';
import 'package:meta/meta.dart';

@immutable
class FeedItem {
  const FeedItem({
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedItem &&
          runtimeType == other.runtimeType &&
          community == other.community &&
          id == other.id &&
          title == other.title &&
          url == other.url &&
          author == other.author &&
          publishedAt == other.publishedAt &&
          recommendCount == other.recommendCount &&
          commentCount == other.commentCount &&
          viewCount == other.viewCount &&
          thumbnailUrl == other.thumbnailUrl &&
          previewText == other.previewText;

  @override
  int get hashCode => Object.hash(
        community,
        id,
        title,
        url,
        author,
        publishedAt,
        recommendCount,
        commentCount,
        viewCount,
        thumbnailUrl,
        previewText,
      );
}
