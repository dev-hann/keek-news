import 'package:equatable/equatable.dart';
import 'package:keek_news/model/comment.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/failures.dart';

sealed class PostDetail extends Equatable {
  const PostDetail();
  int get id;
  CommunityId get community;
}

class LoadedPostDetail extends PostDetail {
  const LoadedPostDetail({
    required this.id,
    required this.community,
    required this.title,
    required this.author,
    required this.date,
    required this.contentBlocks,
    required this.imageUrls,
    required this.recommendCount,
    required this.notRecommendCount,
    required this.viewCount,
    required this.commentCount,
    required this.comments,
  });

  @override
  final int id;
  @override
  final CommunityId community;
  final String title;
  final String author;
  final DateTime date;
  final List<ContentBlock> contentBlocks;
  final List<String> imageUrls;
  final int recommendCount;
  final int notRecommendCount;
  final int viewCount;
  final int commentCount;
  final List<Comment> comments;

  /// True when the page returned no parseable body, images, or comments —
  /// almost always a block/interstitial (HTTP 200 + challenge HTML) rather
  /// than a genuinely empty post.
  bool get looksEmpty =>
      contentBlocks.isEmpty && imageUrls.isEmpty && comments.isEmpty;

  @override
  List<Object?> get props => [
        id,
        title,
        author,
        date,
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

class ErrorPostDetail extends PostDetail {
  const ErrorPostDetail({
    required this.id,
    required this.community,
    required this.failure,
  });

  @override
  final int id;
  @override
  final CommunityId community;
  final Failure failure;

  @override
  List<Object?> get props => [id, community, failure];
}
