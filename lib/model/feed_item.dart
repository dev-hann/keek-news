import 'package:equatable/equatable.dart';
import 'package:keek_news/model/bookmark.dart';
import 'package:keek_news/model/community.dart';

class FeedItem extends Equatable {
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
  });

  factory FeedItem.fromBookmark(Bookmark b) => FeedItem(
        community: b.community,
        id: b.id,
        title: b.title,
        url: b.url,
        author: b.author,
        publishedAt: b.publishedAt,
        recommendCount: b.recommendCount,
        commentCount: b.commentCount,
        viewCount: b.viewCount,
        thumbnailUrl: b.thumbnailUrl,
      );

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

  @override
  List<Object?> get props => [
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
      ];
}
