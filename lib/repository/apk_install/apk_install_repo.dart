import 'package:dartz/dartz.dart';
import 'package:keek_news/model/download_progress.dart';
import 'package:keek_news/model/failures.dart';

/// Repository responsible for downloading the update APK and handing it
/// to the platform's system installer.
///
/// The download is exposed as a [Stream] of [DownloadProgress] events.
/// The stream closes when the download completes successfully; it emits
/// an error event on failure. Callers can treat a clean close (no error)
/// as success.
abstract class ApkInstallRepo {
  /// Downloads the APK at [url], emitting progress events.
  ///
  /// The stream closes on success and emits an error on failure.
  Stream<DownloadProgress> download(String url);

  /// Launches the system installer for the most recently downloaded APK.
  Future<Either<Failure, Unit>> launchInstaller();

  /// Whether the app currently holds the "install unknown apps" permission.
  Future<bool> canRequestPackageInstalls();

  /// Opens the system settings page where the user can grant the install
  /// permission.
  Future<Either<Failure, Unit>> openInstallPermissionSettings();

  /// Cancels any in-progress download and deletes the partial file.
  void cancelDownload();
}
