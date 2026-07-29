import 'package:dartz/dartz.dart';
import 'package:happy_news/core/errors/failures.dart';
import 'package:happy_news/domain/entities/board_list_result.dart';
import 'package:happy_news/domain/entities/sort_option.dart';
import 'package:happy_news/domain/repositories/post_repository.dart';

class GetBoardPosts {
  const GetBoardPosts({required this.repository});
  final PostRepository repository;

  Future<Either<Failure, BoardListResult>> call(
    String table,
    int page,
    SortOption sort,
  ) {
    return repository.getBoardPosts(table, page, sort);
  }
}
