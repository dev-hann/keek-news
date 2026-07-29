import 'package:happy_news/domain/entities/comment.dart';
import 'package:happy_news/domain/entities/content_block.dart';

class CommentDto {
  const CommentDto({
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
  final List<CommentDto> replies;
  final List<ContentBlock> mediaBlocks;

  Comment toEntity() => Comment(
    id: id,
    author: author,
    content: content,
    date: date,
    recommendCount: recommendCount,
    isBest: isBest,
    mediaBlocks: mediaBlocks,
    replies: replies.map((r) => r.toEntity()).toList(),
  );
}
