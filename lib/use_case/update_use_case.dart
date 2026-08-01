import 'package:dartz/dartz.dart';
import 'package:keek_news/model/download_progress.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/update_check_result.dart';
import 'package:keek_news/repository/apk_install/apk_install_repo.dart';
import 'package:keek_news/repository/update/update_repo.dart';
import 'package:keek_news/use_case/base_use_case.dart';

class UpdateUseCase extends BaseUseCase {
  const UpdateUseCase({
    required UpdateRepo updateRepo,
    required ApkInstallRepo apkRepo,
    required this.currentVersion,
  }) : _updateRepo = updateRepo,
       _apkRepo = apkRepo;

  final UpdateRepo _updateRepo;
  final ApkInstallRepo _apkRepo;
  final String currentVersion;

  Future<Either<Failure, UpdateCheckResult>> checkForUpdate() async {
    final result = await guard(_updateRepo.getLatestRelease);
    return result.fold(Left.new, (release) {
      try {
        final isNewer = _isNewerVersion(release.version, currentVersion);
        return Right(
          UpdateCheckResult(
            type: isNewer
                ? UpdateStatusType.updateAvailable
                : UpdateStatusType.upToDate,
            release: release,
          ),
        );
      } catch (_) {
        return const Left(UpdateFailure('Invalid version format'));
      }
    });
  }

  Stream<DownloadProgress> download(String url) => _apkRepo.download(url);

  Future<Either<Failure, Unit>> launchInstaller() =>
      guardUnit(_apkRepo.launchInstaller);

  Future<Either<Failure, bool>> canRequestPackageInstalls() =>
      guard(_apkRepo.canRequestPackageInstalls);

  Future<Either<Failure, Unit>> openInstallPermissionSettings() =>
      guardUnit(_apkRepo.openInstallPermissionSettings);

  void cancelDownload() => _apkRepo.cancelDownload();

  bool _isNewerVersion(String remote, String current) {
    final remoteParts = _parseVersion(remote);
    final currentParts = _parseVersion(current);

    for (var i = 0; i < 3; i++) {
      final r = i < remoteParts.length ? remoteParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (r > c) return true;
      if (r < c) return false;
    }
    return false;
  }

  List<int> _parseVersion(String version) {
    final stripped = version.startsWith('v') || version.startsWith('V')
        ? version.substring(1)
        : version;
    final clean = stripped.split(RegExp('[-+]')).first;
    return clean.split('.').map(int.parse).toList();
  }
}
