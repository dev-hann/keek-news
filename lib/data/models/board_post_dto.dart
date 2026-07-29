import 'package:happy_news/domain/entities/board_post.dart';

class BoardPostDto {
  const BoardPostDto({
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

  BoardPost toEntity() => BoardPost(
    id: id,
    title: title,
    url: url,
    author: author,
    date: date,
    recommendCount: recommendCount,
    notRecommendCount: notRecommendCount,
    commentCount: commentCount,
    viewCount: viewCount,
    thumbnailUrl: thumbnailUrl,
  );
}
