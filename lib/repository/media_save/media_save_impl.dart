import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:keek_news/model/download_progress.dart';
import 'package:keek_news/model/media_save_failure.dart';
import 'package:keek_news/model/media_target.dart';
import 'package:keek_news/repository/media_save/media_save_repo.dart';
import 'package:keek_news/service/gallery_save_service.dart';
import 'package:keek_news/service/media_download_service.dart';
import 'package:keek_news/service/media_share_service.dart';

class MediaSaveImpl implements MediaSaveRepo {
  MediaSaveImpl({
    required MediaDownloadService downloadService,
    required GallerySaveService galleryService,
    required MediaShareService shareService,
  }) : _downloadService = downloadService,
       _galleryService = galleryService,
       _shareService = shareService;

  final MediaDownloadService _downloadService;
  final GallerySaveService _galleryService;
  final MediaShareService _shareService;

  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, Future<Either<MediaSaveFailure, Unit>>> _inFlight = {};

  @override
  Future<Either<MediaSaveFailure, Unit>> saveImage(
    String url, {
    void Function(DownloadProgress progress)? onProgress,
  }) => _guarded(url, () async {
    final path = await _download(
      url,
      fallbackExtension: '.jpg',
      onProgress: onProgress,
    );
    await _galleryService.putImage(path);
    return const Right(unit);
  });

  @override
  Future<Either<MediaSaveFailure, Unit>> saveVideo(
    String url, {
    void Function(DownloadProgress progress)? onProgress,
  }) => _guarded(url, () async {
    final path = await _download(
      url,
      fallbackExtension: '.mp4',
      onProgress: onProgress,
    );
    await _galleryService.putVideo(path);
    return const Right(unit);
  });

  @override
  Future<Either<MediaSaveFailure, Unit>> share(
    MediaTarget target, {
    void Function(DownloadProgress progress)? onProgress,
  }) {
    if (!target.isDownloadable) {
      return _guard(() async {
        await _shareService.shareText(target.url);
        return const Right(unit);
      });
    }
    return _guarded(target.url, () async {
      try {
        final path = await _download(
          target.url,
          fallbackExtension: target.kind == MediaKind.image ? '.jpg' : '.mp4',
          onProgress: onProgress,
        );
        await _shareService.shareFile(path);
        return const Right(unit);
      } on MediaDownloadException catch (e) {
        if (e.canceled) rethrow;
        // Download failed (e.g. hotlink protection): sharing the URL is
        // better than a dead-end, so degrade to a text share.
        await _shareService.shareText(target.url);
        return const Right(unit);
      }
    });
  }

  @override
  void cancel(String url) {
    _cancelTokens.remove(url)?.cancel();
  }

  Future<String> _download(
    String url, {
    required String fallbackExtension,
    void Function(DownloadProgress progress)? onProgress,
  }) {
    final token = CancelToken();
    _cancelTokens[url] = token;
    return _downloadService
        .download(
          url,
          fallbackExtension: fallbackExtension,
          onProgress: onProgress,
          cancelToken: token,
        )
        .whenComplete(() => _cancelTokens.remove(url));
  }

  /// Runs [action] keyed by [url] so the same media is never downloaded
  /// twice concurrently; a second caller gets an inProgress failure.
  Future<Either<MediaSaveFailure, Unit>> _guarded(
    String url,
    Future<Either<MediaSaveFailure, Unit>> Function() action,
  ) async {
    if (_inFlight.containsKey(url)) {
      return const Left(MediaSaveFailure(MediaSaveFailureType.inProgress));
    }
    final future = _guard(action);
    _inFlight[url] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(url)?.ignore();
    }
  }

  Future<Either<MediaSaveFailure, Unit>> _guard(
    Future<Either<MediaSaveFailure, Unit>> Function() action,
  ) async {
    try {
      return await action();
    } on MediaDownloadException catch (e) {
      return Left(
        MediaSaveFailure(
          e.canceled
              ? MediaSaveFailureType.canceled
              : MediaSaveFailureType.network,
          e.detail,
        ),
      );
    } on GallerySaveException catch (e) {
      return Left(
        MediaSaveFailure(
          e.permissionDenied
              ? MediaSaveFailureType.permission
              : MediaSaveFailureType.unexpected,
        ),
      );
    } catch (e) {
      return Left(MediaSaveFailure(MediaSaveFailureType.unexpected, '$e'));
    }
  }
}
