import 'package:dartz/dartz.dart';
import 'package:get_it/get_it.dart';
import 'package:keek_news/model/download_progress.dart';
import 'package:keek_news/model/media_save_failure.dart';
import 'package:keek_news/model/media_target.dart';
import 'package:keek_news/repository/media_save/media_save_repo.dart';
import 'package:keek_news/use_case/copy_media_url_use_case.dart';
import 'package:keek_news/use_case/save_media_use_case.dart';
import 'package:keek_news/use_case/share_media_use_case.dart';

/// Always-succeeding repo double for wiring tests: records calls so tests can
/// assert the sheet talked to the right use case.
class StubMediaSaveRepo implements MediaSaveRepo {
  final List<String> savedImages = [];
  final List<String> savedVideos = [];
  final List<MediaTarget> sharedTargets = [];
  int cancelCount = 0;

  @override
  Future<Either<MediaSaveFailure, Unit>> saveImage(
    String url, {
    void Function(DownloadProgress progress)? onProgress,
  }) async {
    savedImages.add(url);
    return const Right(unit);
  }

  @override
  Future<Either<MediaSaveFailure, Unit>> saveVideo(
    String url, {
    void Function(DownloadProgress progress)? onProgress,
  }) async {
    savedVideos.add(url);
    return const Right(unit);
  }

  @override
  Future<Either<MediaSaveFailure, Unit>> share(
    MediaTarget target, {
    void Function(DownloadProgress progress)? onProgress,
  }) async {
    sharedTargets.add(target);
    return const Right(unit);
  }

  @override
  void cancel(String url) {
    cancelCount++;
  }
}

/// Registers sheet use cases backed by [repo] into GetIt so the sheet
/// helper resolves them in widget tests. Pair with `GetIt.I.reset()` in
/// tearDown.
void registerMediaActionFakes(StubMediaSaveRepo repo) {
  final sl = GetIt.I;
  sl.registerLazySingleton<SaveMediaUseCase>(() => SaveMediaUseCase(repo));
  sl.registerLazySingleton<ShareMediaUseCase>(() => ShareMediaUseCase(repo));
  sl.registerLazySingleton<CopyMediaUrlUseCase>(CopyMediaUrlUseCase.new);
}
