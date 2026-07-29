import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:happy_news/core/errors/failures.dart';
import 'package:happy_news/data/datasources/apk_download_data_source.dart';
import 'package:happy_news/data/datasources/apk_installer_service.dart';
import 'package:happy_news/domain/entities/download_progress.dart';
import 'package:happy_news/domain/repositories/apk_install_repository.dart';

class ApkInstallRepositoryImpl implements ApkInstallRepository {
  ApkInstallRepositoryImpl({
    required ApkDownloadDataSource downloadDataSource,
    required ApkInstallerService installerService,
  }) : _downloadDataSource = downloadDataSource,
       _installerService = installerService;

  final ApkDownloadDataSource _downloadDataSource;
  final ApkInstallerService _installerService;

  StreamController<DownloadProgress>? _controller;

  @override
  Stream<DownloadProgress> download(String url) {
    final controller = StreamController<DownloadProgress>();
    _controller = controller;
    _runDownload(url, controller);
    return controller.stream;
  }

  Future<void> _runDownload(
    String url,
    StreamController<DownloadProgress> controller,
  ) async {
    try {
      await _downloadDataSource.download(url, (received, total) {
        if (!controller.isClosed) {
          controller.add(
            DownloadProgress(receivedBytes: received, totalBytes: total),
          );
        }
      });
      if (!controller.isClosed) {
        await controller.close();
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
        await controller.close();
      }
    }
  }

  @override
  Future<Either<Failure, Unit>> launchInstaller() async {
    final path = _downloadDataSource.savedPath;
    if (path == null) {
      return const Left(UpdateFailure('No downloaded APK to install'));
    }
    try {
      final launched = await _installerService.launchInstaller(path);
      if (!launched) {
        return const Left(UpdateFailure('Installer launch failed'));
      }
      return const Right(unit);
    } catch (e) {
      return Left(UpdateFailure(e.toString()));
    }
  }

  @override
  Future<bool> canRequestPackageInstalls() =>
      _installerService.canRequestPackageInstalls();

  @override
  Future<Either<Failure, Unit>> openInstallPermissionSettings() async {
    try {
      final opened = await _installerService.openInstallPermissionSettings();
      if (!opened) {
        return const Left(UpdateFailure('Could not open install settings'));
      }
      return const Right(unit);
    } catch (e) {
      return Left(UpdateFailure(e.toString()));
    }
  }

  @override
  void cancelDownload() {
    _controller?.close();
    _controller = null;
    _downloadDataSource.cancel();
  }
}
