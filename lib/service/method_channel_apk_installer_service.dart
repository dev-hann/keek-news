import 'package:flutter/services.dart';
import 'package:keek_news/service/apk_installer_service.dart';

class MethodChannelApkInstallerService implements ApkInstallerService {
  MethodChannelApkInstallerService({MethodChannel? methodChannel})
    : _methodChannel = methodChannel ?? const MethodChannel('apk_installer');

  final MethodChannel _methodChannel;

  @override
  Future<bool> launchInstaller(String filePath) async {
    final result = await _methodChannel.invokeMethod<bool>('launchInstaller', {
      'path': filePath,
    });
    return result ?? false;
  }

  @override
  Future<bool> canRequestPackageInstalls() async {
    final result = await _methodChannel.invokeMethod<bool>(
      'canRequestPackageInstalls',
    );
    return result ?? false;
  }

  @override
  Future<bool> openInstallPermissionSettings() async {
    final result = await _methodChannel.invokeMethod<bool>(
      'openInstallPermissionSettings',
    );
    return result ?? false;
  }
}
