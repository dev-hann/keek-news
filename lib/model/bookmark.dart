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

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      community: CommunityId.values.byName(json['community'] as String),
      id: json['id'] as String,
      title: json['title'] as String,
      url: json['url'] as String,
      savedAt: DateTime.fromMillisecondsSinceEpoch(
        json['savedAtMillis'] as int,
      ),
      author: json['author'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      previewText: json['previewText'] as String?,
      publishedAt: (json['publishedAtMillis'] as int?) == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              json['publishedAtMillis'] as int,
            ),
      recommendCount: (json['recommendCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
    );
  }

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

  Map<String, dynamic> toJson() => {
    'community': community.name,
    'id': id,
    'title': title,
    'url': url,
    'savedAtMillis': savedAt.millisecondsSinceEpoch,
    if (author != null) 'author': author,
    if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    if (previewText != null) 'previewText': previewText,
    if (publishedAt != null)
      'publishedAtMillis': publishedAt!.millisecondsSinceEpoch,
    'recommendCount': recommendCount,
    'commentCount': commentCount,
    'viewCount': viewCount,
  };

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
