import 'package:equatable/equatable.dart';
import 'package:keek_news/model/comment.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/content_block.dart';

class PostDetail extends Equatable {
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
  List<Object?> get props => [
    id,
    title,
    author,
    date,
    contentHtml,
    contentBlocks,
    imageUrls,
    recommendCount,
    notRecommendCount,
    viewCount,
    commentCount,
    comments,
    community,
  ];
}
