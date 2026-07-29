import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/data/datasources/apk_installer_service_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('apk_installer');
  late ApkInstallerServiceImpl service;

  Future<Object?> handler(MethodCall call) async {
    switch (call.method) {
      case 'launchInstaller':
        return true;
      case 'canRequestPackageInstalls':
        return true;
      case 'openInstallPermissionSettings':
        return true;
    }
    return null;
  }

  setUp(() {
    service = ApkInstallerServiceImpl(methodChannel: channel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('ApkInstallerServiceImpl', () {
    test('should invoke launchInstaller with the file path', () async {
      final result = await service.launchInstaller('/data/app.apk');

      expect(result, true);
    });

    test('should return false when native side returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => null);

      final result = await service.launchInstaller('/data/app.apk');

      expect(result, false);
    });

    test('should invoke canRequestPackageInstalls', () async {
      final result = await service.canRequestPackageInstalls();

      expect(result, true);
    });

    test('should invoke openInstallPermissionSettings', () async {
      final result = await service.openInstallPermissionSettings();

      expect(result, true);
    });
  });
}
