import 'package:dartz/dartz.dart';
import 'package:happy_news/core/errors/failures.dart';
import 'package:happy_news/domain/entities/post_detail.dart';
import 'package:happy_news/domain/repositories/post_repository.dart';

class GetPostDetail {
  const GetPostDetail({required this.repository});
  final PostRepository repository;

  Future<Either<Failure, PostDetail>> call(String url) {
    return repository.getPostDetail(url);
  }
}
