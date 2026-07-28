import 'package:humoruniv/domain/entities/community.dart';
import 'package:meta/meta.dart';

@immutable
class BoardPost {
  const BoardPost({
    required this.id,
    required this.title,
    required this.url,
    required this.author,
    required this.date,
    required this.recommendCount,
    required this.notRecommendCount,
    required this.commentCount,
    required this.viewCount,
    required this.thumbnailUrl,
    this.previewText,
    this.community = CommunityId.humoruniv,
  });
  final int id;
  final String title;
  final String url;
  final String author;
  final String date;
  final int recommendCount;
  final int notRecommendCount;
  final int commentCount;
  final int viewCount;
  final String thumbnailUrl;
  final String? previewText;
  final CommunityId community;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardPost &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          url == other.url &&
          author == other.author &&
          date == other.date &&
          recommendCount == other.recommendCount &&
          notRecommendCount == other.notRecommendCount &&
          commentCount == other.commentCount &&
          viewCount == other.viewCount &&
          thumbnailUrl == other.thumbnailUrl &&
          previewText == other.previewText &&
          community == other.community;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    url,
    author,
    date,
    recommendCount,
    notRecommendCount,
    commentCount,
    viewCount,
    thumbnailUrl,
    previewText,
    community,
  );
}
