import 'dart:async';

import 'package:keek_news/model/download_progress.dart';
import 'package:keek_news/repository/apk_install/apk_install_repo.dart';
import 'package:keek_news/service/apk_download_service.dart';
import 'package:keek_news/service/apk_installer_service.dart';

class ApkInstallImpl implements ApkInstallRepo {
  ApkInstallImpl({
    required ApkDownloadService downloadDataSource,
    required ApkInstallerService installerService,
  }) : _downloadDataSource = downloadDataSource,
       _installerService = installerService;

  final ApkDownloadService _downloadDataSource;
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
  Future<void> launchInstaller() async {
    final path = _downloadDataSource.savedPath;
    if (path == null) {
      throw StateError('No downloaded APK to install');
    }
    final launched = await _installerService.launchInstaller(path);
    if (!launched) {
      throw StateError('Installer launch failed');
    }
  }

  @override
  Future<bool> canRequestPackageInstalls() {
    return _installerService.canRequestPackageInstalls();
  }

  @override
  Future<void> openInstallPermissionSettings() async {
    final opened = await _installerService.openInstallPermissionSettings();
    if (!opened) {
      throw StateError('Could not open install settings');
    }
  }

  @override
  void cancelDownload() {
    _controller?.close();
    _controller = null;
    _downloadDataSource.cancel();
  }
}
