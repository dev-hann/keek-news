import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keek_news/model/app_release.dart';
import 'package:keek_news/model/download_progress.dart';
import 'package:keek_news/service/service_locator.dart';
import 'package:keek_news/use_case/update_use_case.dart';

enum UpdateCheckStatus {
  idle,
  checking,
  available,
  upToDate,
  error,
  downloading,
  downloadError,
  readyToInstall,
  installPermissionRequired,
}

class UpdateState {
  const UpdateState({
    this.status = UpdateCheckStatus.idle,
    this.release,
    this.downloadProgress,
  });
  final UpdateCheckStatus status;
  final AppRelease? release;
  final DownloadProgress? downloadProgress;

  UpdateState copyWith({
    UpdateCheckStatus? status,
    AppRelease? release,
    DownloadProgress? downloadProgress,
  }) => UpdateState(
    status: status ?? this.status,
    release: release ?? this.release,
    downloadProgress: downloadProgress ?? this.downloadProgress,
  );
}

class UpdateNotifier extends StateNotifier<UpdateState> {
  UpdateNotifier({required UpdateUseCase update})
    : _update = update,
      super(const UpdateState());

  final UpdateUseCase _update;

  StreamSubscription<DownloadProgress>? _downloadSub;
  bool _cancelled = false;

  Future<void> checkForUpdate() async {
    if (state.status == UpdateCheckStatus.checking) return;
    state = const UpdateState(status: UpdateCheckStatus.checking);

    final result = await _update.checkForUpdate();

    result.fold(
      (_) => state = const UpdateState(status: UpdateCheckStatus.error),
      (checkResult) {
        if (checkResult.isUpdateAvailable) {
          state = UpdateState(
            status: UpdateCheckStatus.available,
            release: checkResult.release,
          );
        } else {
          state = UpdateState(
            status: UpdateCheckStatus.upToDate,
            release: checkResult.release,
          );
        }
      },
    );
  }

  /// Starts an in-app download of the available update APK.
  /// Has no effect unless a release with a download URL is available.
  Future<void> downloadUpdate() async {
    final release = state.release;
    final url = release?.downloadUrl;
    if (release == null || url == null) return;

    _cancelled = false;
    state = UpdateState(
      status: UpdateCheckStatus.downloading,
      release: release,
      downloadProgress: const DownloadProgress(receivedBytes: 0, totalBytes: 0),
    );

    _downloadSub = _update
        .download(url)
        .listen(
          (progress) {
            if (_cancelled) return;
            state = UpdateState(
              status: UpdateCheckStatus.downloading,
              release: release,
              downloadProgress: progress,
            );
          },
          onError: (Object _) {
            if (_cancelled) return;
            state = UpdateState(
              status: UpdateCheckStatus.downloadError,
              release: release,
            );
          },
          onDone: () async {
            if (_cancelled) return;
            state = UpdateState(
              status: UpdateCheckStatus.readyToInstall,
              release: release,
            );
            await _tryLaunchInstaller(release);
          },
          cancelOnError: true,
        );
  }

  /// Cancels an in-progress download, returning to the available state so the
  /// user can retry. The downloaded partial file is deleted.
  Future<void> cancelDownload() async {
    _cancelled = true;
    await _downloadSub?.cancel();
    _downloadSub = null;
    _update.cancelDownload();
    final release = state.release;
    if (release != null) {
      state = UpdateState(
        status: UpdateCheckStatus.available,
        release: release,
      );
    }
  }

  /// Launches the system installer for the downloaded APK. If the app lacks
  /// the install permission, transitions to the `installPermissionRequired`
  /// state.
  Future<void> launchInstaller() async {
    final release = state.release;
    if (release == null) return;
    await _tryLaunchInstaller(release);
  }

  Future<void> _tryLaunchInstaller(AppRelease release) async {
    final canInstallResult = await _update.canRequestPackageInstalls();
    final canInstall = canInstallResult.getOrElse(() => false);
    if (!canInstall) {
      state = UpdateState(
        status: UpdateCheckStatus.installPermissionRequired,
        release: release,
      );
      return;
    }
    await _update.launchInstaller();
    // Installer shown. If the user cancels or it fails, the banner stays in
    // readyToInstall so they can retry without re-downloading.
  }

  /// Opens the system settings page to grant the install permission. After the
  /// user returns, the banner stays in installPermissionRequired until they
  /// tap 설치 again.
  Future<void> openInstallPermissionSettings() async {
    await _update.openInstallPermissionSettings();
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    super.dispose();
  }
}

final updateProvider = StateNotifierProvider<UpdateNotifier, UpdateState>(
  (ref) => UpdateNotifier(update: sl<UpdateUseCase>()),
);
