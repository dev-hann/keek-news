/// Abstracts the native Android install machinery behind a Dart interface so
/// that the install flow can be unit-tested without a device.
abstract class ApkInstallerService {
  /// Launches the system installer for the APK at [filePath].
  /// Returns true if the installer was launched successfully.
  Future<bool> launchInstaller(String filePath);

  /// Whether the app is allowed to request package installs (the
  /// "install unknown apps" permission).
  Future<bool> canRequestPackageInstalls();

  /// Opens the system settings page where the user can grant the install
  /// permission. Returns true if the settings page was opened.
  Future<bool> openInstallPermissionSettings();
}
