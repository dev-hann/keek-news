import 'package:dartz/dartz.dart';
import 'package:keek_news/model/download_progress.dart';
import 'package:keek_news/model/media_save_failure.dart';
import 'package:keek_news/model/media_target.dart';
import 'package:keek_news/repository/media_save/media_save_repo.dart';

class SaveMediaUseCase {
  const SaveMediaUseCase(this._repo);

  final MediaSaveRepo _repo;

  Future<Either<MediaSaveFailure, Unit>> call(
    MediaTarget target, {
    void Function(DownloadProgress progress)? onProgress,
  }) {
    return switch (target.kind) {
      MediaKind.image => _repo.saveImage(target.url, onProgress: onProgress),
      MediaKind.video => _repo.saveVideo(target.url, onProgress: onProgress),
      MediaKind.external => Future.value(
        const Left(MediaSaveFailure(MediaSaveFailureType.unexpected)),
      ),
    };
  }

  void cancel(MediaTarget target) => _repo.cancel(target.url);
}
