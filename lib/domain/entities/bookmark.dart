import 'package:happy_news/domain/entities/community.dart';
import 'package:meta/meta.dart';

@immutable
class Bookmark {
  const Bookmark({
    required this.community,
    required this.id,
    required this.title,
    required this.url,
    required this.savedAt,
    this.author,
    this.thumbnailUrl,
    this.previewText,
    this.publishedAt,
    this.recommendCount = 0,
    this.commentCount = 0,
    this.viewCount = 0,
  });

  final CommunityId community;
  final String id;
  final String title;
  final String url;
  final DateTime savedAt;
  final String? author;
  final String? thumbnailUrl;
  final String? previewText;
  final DateTime? publishedAt;
  final int recommendCount;
  final int commentCount;
  final int viewCount;

  String get key => '${community.name}:$id';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bookmark &&
          runtimeType == other.runtimeType &&
          community == other.community &&
          id == other.id &&
          title == other.title &&
          url == other.url &&
          savedAt == other.savedAt &&
          author == other.author &&
          thumbnailUrl == other.thumbnailUrl &&
          previewText == other.previewText &&
          publishedAt == other.publishedAt &&
          recommendCount == other.recommendCount &&
          commentCount == other.commentCount &&
          viewCount == other.viewCount;

  @override
  int get hashCode => Object.hash(
    community,
    id,
    title,
    url,
    savedAt,
    author,
    thumbnailUrl,
    previewText,
    publishedAt,
    recommendCount,
    commentCount,
    viewCount,
  );
}
