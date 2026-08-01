import 'package:dartz/dartz.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/repository/community_repo.dart';

class GetPostDetailUseCase {
  const GetPostDetailUseCase({required this.repos});

  final Map<CommunityId, CommunityRepo> repos;

  Future<Either<Failure, PostDetail>> call({
    required CommunityId community,
    required String id,
  }) async {
    final repo = repos[community];
    if (repo == null) {
      return Left(ServerFailure('No repo for $community'));
    }
    return repo.fetchDetail(id);
  }
}
