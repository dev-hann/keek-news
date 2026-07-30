import 'package:dartz/dartz.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/update_check_result.dart';
import 'package:keek_news/repository/update/update_repo.dart';

class CheckForUpdateUseCase {
  const CheckForUpdateUseCase({
    required this.repository,
    required this.currentVersion,
  });
  final UpdateRepo repository;
  final String currentVersion;

  Future<Either<Failure, UpdateCheckResult>> call() async {
    final result = await repository.getLatestRelease();

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
