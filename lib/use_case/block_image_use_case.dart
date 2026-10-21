import 'package:dartz/dartz.dart';
import 'package:keek_news/model/blocked_image.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/repository/blocked_image/blocked_image_repo.dart';
import 'package:keek_news/use_case/base_use_case.dart';

class BlockImageUseCase extends BaseUseCase {
  const BlockImageUseCase(this._repo);

  final BlockedImageRepo _repo;

  /// Fires after every persisted mutation; forwarded from the repo so the
  /// provider layer never needs the repo directly.
  Stream<void> get changes => _repo.changes;

  Future<Either<Failure, List<BlockedImage>>> getAll() => guard(_repo.getAll);

  Future<Either<Failure, Unit>> add(String url) => guardUnit(
    () => _repo.add(BlockedImage(url: url, blockedAt: DateTime.now())),
  );

  Future<Either<Failure, Unit>> remove(String url) =>
      guardUnit(() => _repo.remove(url));
}
