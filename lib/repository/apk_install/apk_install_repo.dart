import 'package:keek_news/model/download_progress.dart';

abstract class ApkInstallRepo {
  Stream<DownloadProgress> download(String url);

  Future<void> launchInstaller();

  Future<bool> canRequestPackageInstalls();

  Future<void> openInstallPermissionSettings();

  void cancelDownload();
}
