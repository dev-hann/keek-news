import 'package:equatable/equatable.dart';
import 'package:keek_news/model/app_release.dart';

enum UpdateStatusType { upToDate, updateAvailable }

class UpdateCheckResult extends Equatable {
  const UpdateCheckResult({required this.type, required this.release});
  final UpdateStatusType type;
  final AppRelease release;

  bool get isUpdateAvailable => type == UpdateStatusType.updateAvailable;

  @override
  List<Object?> get props => [type, release];
}
