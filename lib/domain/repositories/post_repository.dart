import 'package:dartz/dartz.dart';
import 'package:happy_news/core/errors/failures.dart';
import 'package:happy_news/domain/entities/board_list_result.dart';
import 'package:happy_news/domain/entities/post.dart';
import 'package:happy_news/domain/entities/post_detail.dart';
import 'package:happy_news/domain/entities/sort_option.dart';

abstract class PostRepository {
  Future<Either<Failure, List<Post>>> getBestPosts();
  Future<Either<Failure, PostDetail>> getPostDetail(String url);
  Future<Either<Failure, BoardListResult>> getBoardPosts(
    String table,
    int page,
    SortOption sort,
  );
}
