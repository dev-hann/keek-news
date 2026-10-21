import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:get_it/get_it.dart';
import 'package:keek_news/model/blocked_image.dart';
import 'package:keek_news/model/download_progress.dart';
import 'package:keek_news/model/media_save_failure.dart';
import 'package:keek_news/model/media_target.dart';
import 'package:keek_news/repository/blocked_image/blocked_image_repo.dart';
import 'package:keek_news/repository/media_save/media_save_repo.dart';
import 'package:keek_news/use_case/block_image_use_case.dart';
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

/// In-memory blocklist double: tracks blocked URLs (newest first) and
/// broadcasts [BlockedImageRepo.changes] after each mutation.
class StubBlockedImageRepo implements BlockedImageRepo {
  final List<BlockedImage> _images = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();

  final List<String> addedUrls = [];
  final List<String> removedUrls = [];

  List<String> get blockedUrls => [for (final image in _images) image.url];

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<BlockedImage>> getAll() async => List.of(_images);

  @override
  Future<void> add(BlockedImage image) async {
    addedUrls.add(image.url);
    _images.removeWhere((b) => b.url == image.url);
    _images.insert(0, image);
    _changes.add(null);
  }

  @override
  Future<void> remove(String url) async {
    removedUrls.add(url);
    _images.removeWhere((b) => b.url == url);
    _changes.add(null);
  }
}

/// Registers sheet use cases backed by [repo] into GetIt so the sheet
/// helper resolves them in widget tests. Pair with `GetIt.I.reset()` in
/// tearDown. The blocked-image repo defaults to an empty [StubBlockedImageRepo]
/// and is returned for tests that drive block/unblock.
StubBlockedImageRepo registerMediaActionFakes(
  StubMediaSaveRepo repo, {
  StubBlockedImageRepo? blockedRepo,
}) {
  final stubBlocked = blockedRepo ?? StubBlockedImageRepo();
  final sl = GetIt.I;
  sl.registerLazySingleton<SaveMediaUseCase>(() => SaveMediaUseCase(repo));
  sl.registerLazySingleton<ShareMediaUseCase>(() => ShareMediaUseCase(repo));
  sl.registerLazySingleton<CopyMediaUrlUseCase>(CopyMediaUrlUseCase.new);
  sl.registerLazySingleton<BlockImageUseCase>(
    () => BlockImageUseCase(stubBlocked),
  );
  return stubBlocked;
}
