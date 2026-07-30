import 'package:happy_news/domain/entities/bookmark.dart';
import 'package:happy_news/domain/entities/community.dart';

class BookmarkDto {
  const BookmarkDto({
    required this.community,
    required this.id,
    required this.title,
    required this.url,
    required this.savedAtMillis,
    this.author,
    this.thumbnailUrl,
    this.previewText,
    this.publishedAtMillis,
    this.recommendCount = 0,
    this.commentCount = 0,
    this.viewCount = 0,
  });

  factory BookmarkDto.fromJson(Map<String, dynamic> json) {
    return BookmarkDto(
      community: CommunityId.values.byName(json['community'] as String),
      id: json['id'] as String,
      title: json['title'] as String,
      url: json['url'] as String,
      savedAtMillis: json['savedAtMillis'] as int,
      author: json['author'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      previewText: json['previewText'] as String?,
      publishedAtMillis: json['publishedAtMillis'] as int?,
      recommendCount: (json['recommendCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
    );
  }

  factory BookmarkDto.fromEntity(Bookmark bookmark) {
    return BookmarkDto(
      community: bookmark.community,
      id: bookmark.id,
      title: bookmark.title,
      url: bookmark.url,
      author: bookmark.author,
      thumbnailUrl: bookmark.thumbnailUrl,
      previewText: bookmark.previewText,
      publishedAtMillis: bookmark.publishedAt?.millisecondsSinceEpoch,
      recommendCount: bookmark.recommendCount,
      commentCount: bookmark.commentCount,
      viewCount: bookmark.viewCount,
      savedAtMillis: bookmark.savedAt.millisecondsSinceEpoch,
    );
  }

  final CommunityId community;
  final String id;
  final String title;
  final String url;
  final int savedAtMillis;
  final String? author;
  final String? thumbnailUrl;
  final String? previewText;
  final int? publishedAtMillis;
  final int recommendCount;
  final int commentCount;
  final int viewCount;

  Bookmark toEntity() => Bookmark(
    community: community,
    id: id,
    title: title,
    url: url,
    author: author,
    thumbnailUrl: thumbnailUrl,
    previewText: previewText,
    publishedAt: publishedAtMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(publishedAtMillis!),
    recommendCount: recommendCount,
    commentCount: commentCount,
    viewCount: viewCount,
    savedAt: DateTime.fromMillisecondsSinceEpoch(savedAtMillis),
  );

  Map<String, dynamic> toJson() => {
    'community': community.name,
    'id': id,
    'title': title,
    'url': url,
    'savedAtMillis': savedAtMillis,
    if (author != null) 'author': author,
    if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    if (previewText != null) 'previewText': previewText,
    if (publishedAtMillis != null) 'publishedAtMillis': publishedAtMillis,
    'recommendCount': recommendCount,
    'commentCount': commentCount,
    'viewCount': viewCount,
  };
}
