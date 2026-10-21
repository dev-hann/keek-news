import 'package:dartz/dartz.dart';
import 'package:keek_news/model/blocked_image.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/repository/blocked_image/blocked_image_repo.dart';
import 'package:keek_news/service/image_hash_service.dart';
import 'package:keek_news/use_case/base_use_case.dart';

class BlockImageUseCase extends BaseUseCase {
  const BlockImageUseCase(this._repo, {ImageHashService? hashService})
    : _hashService = hashService;

  final BlockedImageRepo _repo;
  final ImageHashService? _hashService;

  /// Fires after every persisted mutation; forwarded from the repo so the
  /// provider layer never needs the repo directly.
  Stream<void> get changes => _repo.changes;

  /// Whether [hash] fingerprint-matches a blocked image (render-time check).
  bool isHashBlocked(String hash) => _repo.isHashBlocked(hash);

  Future<Either<Failure, List<BlockedImage>>> getAll() => guard(_repo.getAll);

  Future<Either<Failure, Unit>> add(String url) => guardUnit(() async {
    final hash = await _hashService?.hashFor(url);
    await _repo.add(
      BlockedImage(url: url, blockedAt: DateTime.now(), hash: hash),
    );
  });

  Future<Either<Failure, Unit>> remove(String url) =>
      guardUnit(() => _repo.remove(url));
}
