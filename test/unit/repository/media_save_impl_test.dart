import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/download_progress.dart';
import 'package:keek_news/model/media_save_failure.dart';
import 'package:keek_news/model/media_target.dart';
import 'package:keek_news/repository/media_save/media_save_impl.dart';
import 'package:keek_news/service/gallery_save_service.dart';
import 'package:keek_news/service/media_download_service.dart';
import 'package:keek_news/service/media_share_service.dart';

/// Download fake with an optional gate: while [gate] is pending the download
/// hangs, letting tests exercise dedupe/cancel mid-flight. After the gate it
/// throws [error] (if set) or returns [path], honoring a canceled token.
class _FakeDownloadService implements MediaDownloadService {
  _FakeDownloadService({this.path = '/tmp/media.jpg', this.error});

  final String path;
  final Exception? error;

  final List<String> urls = [];
  final List<String?> fallbacks = [];
  Completer<void>? gate;
  CancelToken? lastCancelToken;

  @override
  Future<String> download(
    String url, {
    String fallbackExtension = '',
    void Function(DownloadProgress progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    urls.add(url);
    fallbacks.add(fallbackExtension);
    lastCancelToken = cancelToken;
    onProgress?.call(const DownloadProgress(receivedBytes: 5, totalBytes: 10));
    final pending = gate;
    if (pending != null) await pending.future;
    if (cancelToken != null && cancelToken.isCancelled) {
      throw const MediaDownloadException(canceled: true);
    }
    if (error != null) throw error!;
    return path;
  }
}

class _FakeGalleryService implements GallerySaveService {
  _FakeGalleryService({this.error});

  final Exception? error;
  final List<String> images = [];
  final List<String> videos = [];

  @override
  Future<void> putImage(String path) async {
    images.add(path);
    if (error != null) throw error!;
  }

  @override
  Future<void> putVideo(String path) async {
    videos.add(path);
    if (error != null) throw error!;
  }
}

class _FakeShareService implements MediaShareService {
  _FakeShareService();

  final List<String> files = [];
  final List<String> texts = [];

  @override
  Future<void> shareFile(String path) async {
    files.add(path);
  }

  @override
  Future<void> shareText(String text) async {
    texts.add(text);
  }
}

void main() {
  group('MediaSaveImpl.saveImage', () {
    test('downloads and saves through gallery service', () async {
      final download = _FakeDownloadService(path: '/tmp/a.jpg');
      final gallery = _FakeGalleryService();
      final repo = MediaSaveImpl(
        downloadService: download,
        galleryService: gallery,
        shareService: _FakeShareService(),
      );

      final result = await repo.saveImage('https://x/a.jpg');

      expect(result, const Right<MediaSaveFailure, Unit>(unit));
      expect(download.urls, ['https://x/a.jpg']);
      expect(download.fallbacks, ['.jpg']);
      expect(gallery.images, ['/tmp/a.jpg']);
      expect(gallery.videos, isEmpty);
    });

    test('reports download progress to the caller', () async {
      final progressCalls = <DownloadProgress>[];
      final repo = MediaSaveImpl(
        downloadService: _FakeDownloadService(),
        galleryService: _FakeGalleryService(),
        shareService: _FakeShareService(),
      );

      await repo.saveImage('https://x/a.jpg', onProgress: progressCalls.add);

      expect(progressCalls, isNotEmpty);
      expect(progressCalls.last.percent, 50);
    });

    test('network failure maps to Left(network)', () async {
      final repo = MediaSaveImpl(
        downloadService: _FakeDownloadService(
          error: const MediaDownloadException(canceled: false),
        ),
        galleryService: _FakeGalleryService(),
        shareService: _FakeShareService(),
      );

      final result = await repo.saveImage('https://x/a.jpg');

      expect(
        result.fold((f) => f.type, (_) => null),
        MediaSaveFailureType.network,
      );
    });

    test('permission failure maps to Left(permission)', () async {
      final repo = MediaSaveImpl(
        downloadService: _FakeDownloadService(),
        galleryService: _FakeGalleryService(
          error: const GallerySaveException(permissionDenied: true),
        ),
        shareService: _FakeShareService(),
      );

      final result = await repo.saveImage('https://x/a.jpg');

      expect(
        result.fold((f) => f.type, (_) => null),
        MediaSaveFailureType.permission,
      );
    });

    test('non-permission gallery failure maps to Left(unexpected)', () async {
      final repo = MediaSaveImpl(
        downloadService: _FakeDownloadService(),
        galleryService: _FakeGalleryService(
          error: const GallerySaveException(permissionDenied: false),
        ),
        shareService: _FakeShareService(),
      );

      final result = await repo.saveImage('https://x/a.jpg');

      expect(
        result.fold((f) => f.type, (_) => null),
        MediaSaveFailureType.unexpected,
      );
    });
  });

  group('MediaSaveImpl.saveVideo', () {
    test('downloads with mp4 fallback and saves through gallery', () async {
      final download = _FakeDownloadService(path: '/tmp/v.mp4');
      final gallery = _FakeGalleryService();
      final repo = MediaSaveImpl(
        downloadService: download,
        galleryService: gallery,
        shareService: _FakeShareService(),
      );

      final result = await repo.saveVideo('https://x/clip');

      expect(result, const Right<MediaSaveFailure, Unit>(unit));
      expect(download.fallbacks, ['.mp4']);
      expect(gallery.videos, ['/tmp/v.mp4']);
    });
  });

  group('MediaSaveImpl.cancel + dedupe', () {
    test('cancel mid-download maps to Left(canceled)', () async {
      final download = _FakeDownloadService()..gate = Completer<void>();
      final repo = MediaSaveImpl(
        downloadService: download,
        galleryService: _FakeGalleryService(),
        shareService: _FakeShareService(),
      );

      final future = repo.saveImage('https://x/a.jpg');
      repo.cancel('https://x/a.jpg');
      download.gate!.complete();
      final result = await future;

      expect(
        result.fold((f) => f.type, (_) => null),
        MediaSaveFailureType.canceled,
      );
      expect(download.lastCancelToken?.isCancelled, isTrue);
    });

    test(
      'second save for the same url while in flight gets inProgress',
      () async {
        final download = _FakeDownloadService()..gate = Completer<void>();
        final repo = MediaSaveImpl(
          downloadService: download,
          galleryService: _FakeGalleryService(),
          shareService: _FakeShareService(),
        );

        final first = repo.saveImage('https://x/a.jpg');
        final second = await repo.saveImage('https://x/a.jpg');
        download.gate!.complete();
        final firstResult = await first;

        expect(firstResult, const Right<MediaSaveFailure, Unit>(unit));
        expect(
          second.fold((f) => f.type, (_) => null),
          MediaSaveFailureType.inProgress,
        );
      },
    );

    test('cancel with no in-flight download is a no-op', () {
      final repo = MediaSaveImpl(
        downloadService: _FakeDownloadService(),
        galleryService: _FakeGalleryService(),
        shareService: _FakeShareService(),
      );

      expect(() => repo.cancel('https://x/none.jpg'), returnsNormally);
    });

    test(
      'in-flight entry is cleared after completion so retry works',
      () async {
        final download = _FakeDownloadService()..gate = Completer<void>();
        final repo = MediaSaveImpl(
          downloadService: download,
          galleryService: _FakeGalleryService(),
          shareService: _FakeShareService(),
        );

        final first = repo.saveImage('https://x/a.jpg');
        download.gate!.complete();
        await first;
        final second = await repo.saveImage('https://x/a.jpg');

        expect(second, const Right<MediaSaveFailure, Unit>(unit));
        expect(download.urls.length, 2);
      },
    );
  });

  group('MediaSaveImpl.share', () {
    test(
      'external target shares the url as text without downloading',
      () async {
        final download = _FakeDownloadService();
        final share = _FakeShareService();
        final repo = MediaSaveImpl(
          downloadService: download,
          galleryService: _FakeGalleryService(),
          shareService: share,
        );

        final result = await repo.share(
          MediaTarget.video(
            const VideoBlock(url: 'https://youtu.be/abc12345678'),
          ),
        );

        expect(result, const Right<MediaSaveFailure, Unit>(unit));
        expect(share.texts, ['https://youtu.be/abc12345678']);
        expect(download.urls, isEmpty);
        expect(share.files, isEmpty);
      },
    );

    test('image target downloads then shares the file', () async {
      final share = _FakeShareService();
      final repo = MediaSaveImpl(
        downloadService: _FakeDownloadService(path: '/tmp/a.jpg'),
        galleryService: _FakeGalleryService(),
        shareService: share,
      );

      final result = await repo.share(MediaTarget.image('https://x/a.jpg'));

      expect(result, const Right<MediaSaveFailure, Unit>(unit));
      expect(share.files, ['/tmp/a.jpg']);
    });

    test('download failure falls back to sharing the url as text', () async {
      final share = _FakeShareService();
      final repo = MediaSaveImpl(
        downloadService: _FakeDownloadService(
          error: const MediaDownloadException(canceled: false),
        ),
        galleryService: _FakeGalleryService(),
        shareService: share,
      );

      final result = await repo.share(MediaTarget.image('https://x/a.jpg'));

      expect(result, const Right<MediaSaveFailure, Unit>(unit));
      expect(share.texts, ['https://x/a.jpg']);
      expect(share.files, isEmpty);
    });

    test('user cancel does not fall back to a text share', () async {
      final download = _FakeDownloadService()..gate = Completer<void>();
      final share = _FakeShareService();
      final repo = MediaSaveImpl(
        downloadService: download,
        galleryService: _FakeGalleryService(),
        shareService: share,
      );

      final future = repo.share(MediaTarget.image('https://x/a.jpg'));
      repo.cancel('https://x/a.jpg');
      download.gate!.complete();
      final result = await future;

      expect(
        result.fold((f) => f.type, (_) => null),
        MediaSaveFailureType.canceled,
      );
      expect(share.texts, isEmpty);
      expect(share.files, isEmpty);
    });
  });
}
