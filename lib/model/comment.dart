import 'package:equatable/equatable.dart';
import 'package:keek_news/model/content_block.dart';

class Comment extends Equatable {
  const Comment({
    required this.id,
    required this.author,
    required this.content,
    required this.date,
    required this.recommendCount,
    required this.isBest,
    required this.replies,
    this.mediaBlocks = const [],
  });
  final int id;
  final String author;
  final String content;
  final DateTime date;
  final int recommendCount;
  final bool isBest;
  final List<ContentBlock> mediaBlocks;
  final List<Comment> replies;

  List<String> get imageUrls =>
      mediaBlocks.whereType<ImageBlock>().map((b) => b.url).toList();

  @override
  List<Object?> get props => [
    id,
    author,
    content,
    date,
    recommendCount,
    isBest,
    mediaBlocks,
    replies,
  ];
}
