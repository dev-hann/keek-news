import 'package:dartz/dartz.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/repository/cache/image_cache_repo.dart';
import 'package:keek_news/use_case/base_use_case.dart';

class CacheUseCase extends BaseUseCase {
  const CacheUseCase(this._repo);

  final ImageCacheRepo _repo;

  Future<Either<Failure, int>> getSizeBytes() => guard(_repo.getSizeBytes);

  Future<Either<Failure, Unit>> clear() => guardUnit(_repo.clear);
}
