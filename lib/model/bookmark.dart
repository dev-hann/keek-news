import 'package:equatable/equatable.dart';
import 'package:keek_news/model/community.dart';

class Bookmark extends Equatable {
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
  List<Object?> get props => [
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
  ];
}
