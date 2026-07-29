import 'package:dartz/dartz.dart';
import 'package:happy_news/core/errors/failures.dart';
import 'package:happy_news/domain/entities/post.dart';
import 'package:happy_news/domain/repositories/post_repository.dart';

class GetBestPosts {
  const GetBestPosts({required this.repository});
  final PostRepository repository;

  Future<Either<Failure, List<Post>>> call() async {
    return repository.getBestPosts();
  }
}
