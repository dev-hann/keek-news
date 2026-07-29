import 'package:happy_news/domain/entities/post.dart';

class PostDto {
  const PostDto({
    required this.id,
    required this.title,
    required this.recommendCount,
    required this.url,
  });
  final int id;
  final String title;
  final int recommendCount;
  final String url;

  Post toEntity() =>
      Post(id: id, title: title, recommendCount: recommendCount, url: url);
}
