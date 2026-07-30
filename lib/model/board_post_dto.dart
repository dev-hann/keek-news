import 'package:equatable/equatable.dart';
import 'package:keek_news/model/board_post.dart';

class BoardPostDto extends Equatable {
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

  @override
  List<Object?> get props => [
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
  ];
}
