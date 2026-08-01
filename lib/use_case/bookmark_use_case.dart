import 'package:dartz/dartz.dart';
import 'package:keek_news/model/bookmark.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/repository/bookmark/bookmark_repo.dart';
import 'package:keek_news/use_case/base_use_case.dart';

class BookmarkUseCase extends BaseUseCase {
  const BookmarkUseCase(this._repo);

  final BookmarkRepo _repo;

  Future<Either<Failure, List<Bookmark>>> getAll() => guard(_repo.getAll);

  Future<Either<Failure, bool>> isBookmarked(
    CommunityId community,
    String id,
  ) => guard(() => _repo.isBookmarked(community, id));

  Future<Either<Failure, Unit>> add(Bookmark bookmark) =>
      guardUnit(() => _repo.add(bookmark));

  Future<Either<Failure, Unit>> remove(CommunityId community, String id) =>
      guardUnit(() => _repo.remove(community, id));
}
