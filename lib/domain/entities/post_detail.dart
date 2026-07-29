import 'package:happy_news/domain/entities/comment.dart';
import 'package:happy_news/domain/entities/community.dart';
import 'package:happy_news/domain/entities/content_block.dart';
import 'package:meta/meta.dart';

@immutable
class PostDetail {
  const PostDetail({
    required this.id,
    required this.title,
    required this.author,
    required this.date,
    required this.contentHtml,
    required this.contentBlocks,
    required this.imageUrls,
    required this.recommendCount,
    required this.notRecommendCount,
    required this.viewCount,
    required this.commentCount,
    required this.comments,
    this.community = CommunityId.humoruniv,
  });
  final int id;
  final String title;
  final String author;
  final DateTime date;
  final String contentHtml;
  final List<ContentBlock> contentBlocks;
  final List<String> imageUrls;
  final int recommendCount;
  final int notRecommendCount;
  final int viewCount;
  final int commentCount;
  final List<Comment> comments;
  final CommunityId community;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostDetail &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          author == other.author &&
          date == other.date &&
          contentHtml == other.contentHtml &&
          recommendCount == other.recommendCount &&
          notRecommendCount == other.notRecommendCount &&
          viewCount == other.viewCount &&
          commentCount == other.commentCount &&
          community == other.community;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    author,
    date,
    contentHtml,
    recommendCount,
    notRecommendCount,
    viewCount,
    commentCount,
    community,
  );
}
