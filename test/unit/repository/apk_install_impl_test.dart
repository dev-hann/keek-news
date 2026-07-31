import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/repository/apk_install/apk_install_impl.dart';
import 'package:keek_news/service/apk_download_service.dart';
import 'package:keek_news/service/apk_installer_service.dart';
import 'package:mocktail/mocktail.dart';

class MockApkInstallerService extends Mock implements ApkInstallerService {}

/// Fake datasource whose download behaviour is controllable per test.
class FakeApkDownloadService implements ApkDownloadService {
  FakeApkDownloadService({this.progressEvents = const []});

  /// (received, total) pairs to emit before completing.
  final List<({int received, int total})> progressEvents;
  Object? errorToThrow;
  bool cancelCalled = false;

  @override
  String? savedPath;

  @override
  Future<String> download(
    String url,
    void Function(int receivedBytes, int totalBytes) onProgress,
  ) async {
    savedPath = '/tmp/fake.apk';
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    for (final e in progressEvents) {
      onProgress(e.received, e.total);
    }
    return savedPath!;
  }

  @override
  void cancel() {
    cancelCalled = true;
    savedPath = null;
  }
}

void main() {
  late MockApkInstallerService mockInstaller;
  late ApkInstallImpl repository;

  setUp(() {
    mockInstaller = MockApkInstallerService();
  });

  group('ApkInstallImpl.download', () {
    test('should emit progress events then close on success', () async {
      final ds = FakeApkDownloadService(
        progressEvents: [
          (received: 0, total: 100),
          (received: 50, total: 100),
          (received: 100, total: 100),
        ],
      );
      repository = ApkInstallImpl(
        downloadDataSource: ds,
        installerService: mockInstaller,
      );

      final events = await repository
          .download('https://example.com/app.apk')
          .toList();

      expect(events.length, 3);
      expect(events.last.percent, 100);
    });

    test('should emit an error when the download fails', () async {
      final ds = FakeApkDownloadService();
      ds.errorToThrow = Exception('network down');
      repository = ApkInstallImpl(
        downloadDataSource: ds,
        installerService: mockInstaller,
      );

      expect(
        () => repository.download('https://example.com/app.apk').toList(),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('ApkInstallImpl.launchInstaller', () {
    test(
      'should return Right(unit) when a file is saved and service succeeds',
      () async {
        final ds = FakeApkDownloadService()..savedPath = '/tmp/fake.apk';
        repository = ApkInstallImpl(
          downloadDataSource: ds,
          installerService: mockInstaller,
        );
        when(
          () => mockInstaller.launchInstaller('/tmp/fake.apk'),
        ).thenAnswer((_) async => true);

        final result = await repository.launchInstaller();

        expect(result.isRight(), true);
      },
    );

    test('should return Left when no APK has been downloaded', () async {
      final ds = FakeApkDownloadService(); // savedPath == null
      repository = ApkInstallImpl(
        downloadDataSource: ds,
        installerService: mockInstaller,
      );

      final result = await repository.launchInstaller();

      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<UpdateFailure>()), (_) => fail('Left'));
    });

    test(
      'should return Left when the installer service returns false',
      () async {
        final ds = FakeApkDownloadService()..savedPath = '/tmp/fake.apk';
        repository = ApkInstallImpl(
          downloadDataSource: ds,
          installerService: mockInstaller,
        );
        when(
          () => mockInstaller.launchInstaller(any()),
        ).thenAnswer((_) async => false);

        final result = await repository.launchInstaller();

        expect(result.isLeft(), true);
      },
    );
  });

  group('ApkInstallImpl.permissions', () {
    test('canRequestPackageInstalls delegates to service', () async {
      final ds = FakeApkDownloadService();
      repository = ApkInstallImpl(
        downloadDataSource: ds,
        installerService: mockInstaller,
      );
      when(
        () => mockInstaller.canRequestPackageInstalls(),
      ).thenAnswer((_) async => true);

      final result = await repository.canRequestPackageInstalls();

      expect(result, true);
    });

    test(
      'openInstallPermissionSettings returns Right when service opens',
      () async {
        final ds = FakeApkDownloadService();
        repository = ApkInstallImpl(
          downloadDataSource: ds,
          installerService: mockInstaller,
        );
        when(
          () => mockInstaller.openInstallPermissionSettings(),
        ).thenAnswer((_) async => true);

        final result = await repository.openInstallPermissionSettings();

        expect(result.isRight(), true);
      },
    );
  });

  group('ApkInstallImpl.cancelDownload', () {
    test('should cancel the download datasource', () async {
      final ds = FakeApkDownloadService();
      repository = ApkInstallImpl(
        downloadDataSource: ds,
        installerService: mockInstaller,
      );

      repository.cancelDownload();

      expect(ds.cancelCalled, true);
    });
  });
}
