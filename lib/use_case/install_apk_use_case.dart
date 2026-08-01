import 'package:dartz/dartz.dart';
import 'package:keek_news/model/download_progress.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/repository/apk_install/apk_install_repo.dart';

class InstallApkUseCase {
  const InstallApkUseCase(this._repo);

  final ApkInstallRepo _repo;

  Stream<DownloadProgress> download(String url) => _repo.download(url);

  Future<Either<Failure, Unit>> launchInstaller() => _repo.launchInstaller();

  Future<bool> canRequestPackageInstalls() {
    return _repo.canRequestPackageInstalls();
  }

  Future<Either<Failure, Unit>> openInstallPermissionSettings() {
    return _repo.openInstallPermissionSettings();
  }

  void cancelDownload() => _repo.cancelDownload();
}
