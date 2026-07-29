import 'package:happy_news/domain/entities/app_release.dart';
import 'package:meta/meta.dart';

enum UpdateStatusType { upToDate, updateAvailable }

@immutable
class UpdateCheckResult {
  const UpdateCheckResult({required this.type, required this.release});
  final UpdateStatusType type;
  final AppRelease release;

  bool get isUpdateAvailable => type == UpdateStatusType.updateAvailable;
}
