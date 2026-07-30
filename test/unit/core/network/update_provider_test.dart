import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/errors/failures.dart';
import 'package:happy_news/di/injection.dart' as di;
import 'package:happy_news/domain/entities/app_release.dart';
import 'package:happy_news/domain/entities/download_progress.dart';
import 'package:happy_news/domain/repositories/apk_install_repository.dart';
import 'package:happy_news/domain/repositories/update_repository.dart';
import 'package:happy_news/domain/usecases/check_for_update.dart';
import 'package:happy_news/presentation/providers/update_provider.dart';
import 'package:mocktail/mocktail.dart';

class MockUpdateRepository extends Mock implements UpdateRepository {}

class MockApkInstallRepository extends Mock implements ApkInstallRepository {}

const _availableRelease = AppRelease(
  version: '1.2.0',
  htmlUrl: 'https://example.com',
  downloadUrl: 'https://example.com/app.apk',
);

UpdateNotifier _notifierWith({
  required MockApkInstallRepository apkRepo,
  String currentVersion = '1.0.0',
}) {
  final checkRepo = MockUpdateRepository();
  when(
    checkRepo.getLatestRelease,
  ).thenAnswer((_) async => const Right(_availableRelease));
  return UpdateNotifier(
    checkForUpdate: CheckForUpdate(
      repository: checkRepo,
      currentVersion: currentVersion,
    ),
    apkInstallRepository: apkRepo,
  );
}

void main() {
  late MockUpdateRepository mockRepository;
  late MockApkInstallRepository mockApkRepo;

  setUp(() {
    mockRepository = MockUpdateRepository();
    mockApkRepo = MockApkInstallRepository();
    if (di.sl.isRegistered<UpdateRepository>()) {
      di.sl.unregister<UpdateRepository>();
    }
    if (di.sl.isRegistered<CheckForUpdate>()) {
      di.sl.unregister<CheckForUpdate>();
    }
    if (di.sl.isRegistered<ApkInstallRepository>()) {
      di.sl.unregister<ApkInstallRepository>();
    }
    di.sl.registerLazySingleton<UpdateRepository>(() => mockRepository);
    di.sl.registerLazySingleton(
      () => CheckForUpdate(repository: mockRepository, currentVersion: '1.0.0'),
    );
    di.sl.registerLazySingleton<ApkInstallRepository>(() => mockApkRepo);
  });

  tearDown(di.sl.reset);

  group('UpdateState', () {
    test('copyWith updates status only', () {
      const state = UpdateState(
        release: AppRelease(version: '1.0.0', htmlUrl: 'https://example.com'),
      );
      final copied = state.copyWith(status: UpdateCheckStatus.checking);

      expect(copied.status, UpdateCheckStatus.checking);
      expect(copied.release?.version, '1.0.0');
    });

    test('copyWith updates release only', () {
      const state = UpdateState();
      const newRelease = AppRelease(
        version: '2.0.0',
        htmlUrl: 'https://example.com/v2',
      );
      final copied = state.copyWith(release: newRelease);

      expect(copied.status, UpdateCheckStatus.idle);
      expect(copied.release?.version, '2.0.0');
    });

    test('copyWith with no args returns identical state', () {
      const state = UpdateState(
        status: UpdateCheckStatus.available,
        release: AppRelease(version: '1.0.0', htmlUrl: 'https://example.com'),
      );
      final copied = state.copyWith();

      expect(copied.status, state.status);
      expect(copied.release?.version, state.release?.version);
    });

    test('copyWith updates both fields', () {
      const state = UpdateState();
      const newRelease = AppRelease(
        version: '2.0.0',
        htmlUrl: 'https://example.com/v2',
      );
      final copied = state.copyWith(
        status: UpdateCheckStatus.available,
        release: newRelease,
      );

      expect(copied.status, UpdateCheckStatus.available);
      expect(copied.release?.version, '2.0.0');
    });

    test('default state has idle status and null release', () {
      const state = UpdateState();

      expect(state.status, UpdateCheckStatus.idle);
      expect(state.release, isNull);
    });
  });

  group('updateProvider', () {
    test('should emit idle initially', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(updateProvider);

      expect(state.status, UpdateCheckStatus.idle);
    });

    test('should emit available when update found', () async {
      const release = AppRelease(
        version: '1.2.0',
        htmlUrl: 'https://example.com',
      );
      when(
        () => mockRepository.getLatestRelease(),
      ).thenAnswer((_) async => const Right(release));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(updateProvider.notifier).checkForUpdate();

      final state = container.read(updateProvider);
      expect(state.status, UpdateCheckStatus.available);
      expect(state.release?.version, '1.2.0');
    });

    test('should emit upToDate when no update', () async {
      const release = AppRelease(
        version: '1.0.0',
        htmlUrl: 'https://example.com',
      );
      when(
        () => mockRepository.getLatestRelease(),
      ).thenAnswer((_) async => const Right(release));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(updateProvider.notifier).checkForUpdate();

      final state = container.read(updateProvider);
      expect(state.status, UpdateCheckStatus.upToDate);
    });

    test('should emit error on failure', () async {
      when(
        () => mockRepository.getLatestRelease(),
      ).thenAnswer((_) async => const Left(UpdateFailure('Network error')));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(updateProvider.notifier).checkForUpdate();

      final state = container.read(updateProvider);
      expect(state.status, UpdateCheckStatus.error);
      expect(state.release, isNull);
    });

    test('should set release on upToDate', () async {
      const release = AppRelease(
        version: '1.0.0',
        htmlUrl: 'https://example.com',
        downloadUrl: 'https://example.com/app.apk',
      );
      when(
        () => mockRepository.getLatestRelease(),
      ).thenAnswer((_) async => const Right(release));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(updateProvider.notifier).checkForUpdate();

      final state = container.read(updateProvider);
      expect(state.status, UpdateCheckStatus.upToDate);
      expect(state.release?.version, '1.0.0');
      expect(state.release?.downloadUrl, 'https://example.com/app.apk');
    });

    test('should emit checking while in progress', () async {
      final completer = Completer<Either<Failure, AppRelease>>();
      when(
        () => mockRepository.getLatestRelease(),
      ).thenAnswer((_) => completer.future);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(updateProvider.notifier).checkForUpdate();

      final state = container.read(updateProvider);
      expect(state.status, UpdateCheckStatus.checking);

      completer.complete(
        const Right(
          AppRelease(version: '1.0.0', htmlUrl: 'https://example.com'),
        ),
      );
      await container.read(updateProvider.notifier).stream.first;
    });
  });

  group('UpdateNotifier download/install flow', () {
    test(
      'downloadUpdate emits downloading then readyToInstall on success',
      () async {
        final apkRepo = MockApkInstallRepository();
        final notifier = _notifierWith(apkRepo: apkRepo);
        addTearDown(notifier.dispose);

        // Seed the available state first.
        await notifier.checkForUpdate();
        expect(notifier.state.status, UpdateCheckStatus.available);

        final progressController = StreamController<DownloadProgress>();
        when(
          () => apkRepo.download('https://example.com/app.apk'),
        ).thenAnswer((_) => progressController.stream);
        when(apkRepo.canRequestPackageInstalls).thenAnswer((_) async => true);
        when(
          apkRepo.launchInstaller,
        ).thenAnswer((_) async => const Right(unit));

        await notifier.downloadUpdate();
        expect(notifier.state.status, UpdateCheckStatus.downloading);

        progressController.add(
          const DownloadProgress(receivedBytes: 50, totalBytes: 100),
        );
        await Future<void>.delayed(Duration.zero);
        expect(notifier.state.downloadProgress?.percent, 50);

        await progressController.close();
        // onDone transitions to readyToInstall then tries to launch the installer.
        await Future<void>.delayed(Duration.zero);

        expect(notifier.state.status, UpdateCheckStatus.readyToInstall);
      },
    );

    test('downloadUpdate sets downloadError on stream error', () async {
      final apkRepo = MockApkInstallRepository();
      final notifier = _notifierWith(apkRepo: apkRepo);
      addTearDown(notifier.dispose);
      await notifier.checkForUpdate();

      final progressController = StreamController<DownloadProgress>();
      when(
        () => apkRepo.download(any()),
      ).thenAnswer((_) => progressController.stream);

      await notifier.downloadUpdate();
      progressController.addError(Exception('network down'));
      await progressController.close();
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.status, UpdateCheckStatus.downloadError);
    });

    test('cancelDownload returns to available and cancels the repo', () async {
      final apkRepo = MockApkInstallRepository();
      final notifier = _notifierWith(apkRepo: apkRepo);
      addTearDown(notifier.dispose);
      await notifier.checkForUpdate();

      final progressController = StreamController<DownloadProgress>();
      when(
        () => apkRepo.download(any()),
      ).thenAnswer((_) => progressController.stream);

      await notifier.downloadUpdate();
      expect(notifier.state.status, UpdateCheckStatus.downloading);

      await notifier.cancelDownload();

      expect(notifier.state.status, UpdateCheckStatus.available);
      verify(apkRepo.cancelDownload).called(1);
      await progressController.close();
    });

    test(
      'launchInstaller can be re-invoked from readyToInstall (install retry)',
      () async {
        final apkRepo = MockApkInstallRepository();
        final notifier = _notifierWith(apkRepo: apkRepo);
        addTearDown(notifier.dispose);
        await notifier.checkForUpdate();

        final progressController = StreamController<DownloadProgress>();
        when(
          () => apkRepo.download(any()),
        ).thenAnswer((_) => progressController.stream);
        when(apkRepo.canRequestPackageInstalls).thenAnswer((_) async => true);
        when(
          apkRepo.launchInstaller,
        ).thenAnswer((_) async => const Right(unit));

        await notifier.downloadUpdate();
        await progressController.close();
        await Future<void>.delayed(Duration.zero);

        expect(notifier.state.status, UpdateCheckStatus.readyToInstall);

        // Simulate the user cancelling the system dialog then tapping 설치 again.
        await notifier.launchInstaller();

        verify(apkRepo.launchInstaller).called(2);
      },
    );

    test(
      'without permission transitions to installPermissionRequired',
      () async {
        final apkRepo = MockApkInstallRepository();
        final notifier = _notifierWith(apkRepo: apkRepo);
        addTearDown(notifier.dispose);
        await notifier.checkForUpdate();

        final progressController = StreamController<DownloadProgress>();
        when(
          () => apkRepo.download(any()),
        ).thenAnswer((_) => progressController.stream);
        when(apkRepo.canRequestPackageInstalls).thenAnswer((_) async => false);

        await notifier.downloadUpdate();
        await progressController.close();
        await Future<void>.delayed(Duration.zero);

        expect(
          notifier.state.status,
          UpdateCheckStatus.installPermissionRequired,
        );
        verifyNever(apkRepo.launchInstaller);
      },
    );
  });
}
