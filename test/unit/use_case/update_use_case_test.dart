import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/app_release.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/update_check_result.dart';
import 'package:keek_news/repository/apk_install/apk_install_repo.dart';
import 'package:keek_news/repository/update/update_repo.dart';
import 'package:keek_news/use_case/update_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockUpdateRepository extends Mock implements UpdateRepo {}

class MockApkInstallRepo extends Mock implements ApkInstallRepo {}

void main() {
  late MockUpdateRepository mockRepository;
  late MockApkInstallRepo mockApkRepo;
  late UpdateUseCase useCase;

  setUp(() {
    mockRepository = MockUpdateRepository();
    mockApkRepo = MockApkInstallRepo();
    useCase = UpdateUseCase(
      updateRepo: mockRepository,
      apkRepo: mockApkRepo,
      currentVersion: '1.0.0',
    );
  });

  group('UpdateUseCase', () {
    test(
      'should return updateAvailable when remote version is newer',
      () async {
        const release = AppRelease(
          version: '1.2.0',
          htmlUrl: 'https://github.com/dev-hann/humoruniv/releases/tag/v1.2.0',
          downloadUrl: 'https://example.com/app.apk',
        );
        when(
          () => mockRepository.getLatestRelease(),
        ).thenAnswer((_) async => release);

        final result = await useCase.checkForUpdate();

        expect(result.isRight(), true);
        result.fold((_) => fail('Should be Right'), (status) {
          expect(status.isUpdateAvailable, true);
          expect(status.release.version, '1.2.0');
        });
      },
    );

    test('should return upToDate when versions match', () async {
      const release = AppRelease(
        version: '1.0.0',
        htmlUrl: 'https://github.com/dev-hann/humoruniv/releases/tag/v1.0.0',
      );
      when(
        () => mockRepository.getLatestRelease(),
      ).thenAnswer((_) async => release);

      final result = await useCase.checkForUpdate();

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should be Right'),
        (status) => expect(status.isUpdateAvailable, false),
      );
    });

    test('should return upToDate when remote version is older', () async {
      const release = AppRelease(
        version: '0.9.0',
        htmlUrl: 'https://github.com/dev-hann/humoruniv/releases/tag/v0.9.0',
      );
      when(
        () => mockRepository.getLatestRelease(),
      ).thenAnswer((_) async => release);

      final result = await useCase.checkForUpdate();

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should be Right'),
        (status) => expect(status.isUpdateAvailable, false),
      );
    });

    test('should return failure when repository fails', () async {
      const failure = UpdateFailure('Network error');
      when(
        () => mockRepository.getLatestRelease(),
      ).thenAnswer((_) async => throw failure);

      final result = await useCase.checkForUpdate();

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<UpdateFailure>()),
        (_) => fail('Should be Left'),
      );
    });

    test('should correctly compare patch versions', () async {
      final useCase = UpdateUseCase(
        updateRepo: mockRepository,
        apkRepo: mockApkRepo,
        currentVersion: '1.0.1',
      );
      const release = AppRelease(
        version: '1.0.2',
        htmlUrl: 'https://example.com',
      );
      when(
        () => mockRepository.getLatestRelease(),
      ).thenAnswer((_) async => release);

      final result = await useCase.checkForUpdate();

      result.fold(
        (_) => fail('Should be Right'),
        (status) => expect(status.isUpdateAvailable, true),
      );
    });

    test('should correctly compare major versions', () async {
      final useCase = UpdateUseCase(
        updateRepo: mockRepository,
        apkRepo: mockApkRepo,
        currentVersion: '1.99.99',
      );
      const release = AppRelease(
        version: '2.0.0',
        htmlUrl: 'https://example.com',
      );
      when(
        () => mockRepository.getLatestRelease(),
      ).thenAnswer((_) async => release);

      final result = await useCase.checkForUpdate();

      result.fold(
        (_) => fail('Should be Right'),
        (status) => expect(status.isUpdateAvailable, true),
      );
    });

    test('should handle short remote version with 2 parts', () async {
      final useCase = UpdateUseCase(
        updateRepo: mockRepository,
        apkRepo: mockApkRepo,
        currentVersion: '1.0.0',
      );
      const release = AppRelease(
        version: '1.2',
        htmlUrl: 'https://example.com',
      );
      when(
        () => mockRepository.getLatestRelease(),
      ).thenAnswer((_) async => release);

      final result = await useCase.checkForUpdate();

      result.fold(
        (_) => fail('Should be Right'),
        (status) => expect(status.isUpdateAvailable, true),
      );
    });

    test('should handle short remote version with 1 part', () async {
      final useCase = UpdateUseCase(
        updateRepo: mockRepository,
        apkRepo: mockApkRepo,
        currentVersion: '1.0.0',
      );
      const release = AppRelease(version: '2', htmlUrl: 'https://example.com');
      when(
        () => mockRepository.getLatestRelease(),
      ).thenAnswer((_) async => release);

      final result = await useCase.checkForUpdate();

      result.fold(
        (_) => fail('Should be Right'),
        (status) => expect(status.isUpdateAvailable, true),
      );
    });

    test('should handle short current version with 1 part', () async {
      final useCase = UpdateUseCase(
        updateRepo: mockRepository,
        apkRepo: mockApkRepo,
        currentVersion: '1',
      );
      const release = AppRelease(
        version: '1.0.1',
        htmlUrl: 'https://example.com',
      );
      when(
        () => mockRepository.getLatestRelease(),
      ).thenAnswer((_) async => release);

      final result = await useCase.checkForUpdate();

      result.fold(
        (_) => fail('Should be Right'),
        (status) => expect(status.isUpdateAvailable, true),
      );
    });

    test('should preserve release fields through result', () async {
      const release = AppRelease(
        version: '1.2.0',
        htmlUrl: 'https://example.com/v1.2.0',
        downloadUrl: 'https://example.com/app.apk',
        releaseNotes: 'Bug fixes',
      );
      when(
        () => mockRepository.getLatestRelease(),
      ).thenAnswer((_) async => release);

      final result = await useCase.checkForUpdate();

      result.fold((_) => fail('Should be Right'), (status) {
        expect(status.release.htmlUrl, 'https://example.com/v1.2.0');
        expect(status.release.downloadUrl, 'https://example.com/app.apk');
        expect(status.release.releaseNotes, 'Bug fixes');
      });
    });

    test('should set correct UpdateStatusType on result', () async {
      const release = AppRelease(
        version: '1.2.0',
        htmlUrl: 'https://example.com',
      );
      when(
        () => mockRepository.getLatestRelease(),
      ).thenAnswer((_) async => release);

      final result = await useCase.checkForUpdate();

      result.fold((_) => fail('Should be Right'), (status) {
        expect(status.type, UpdateStatusType.updateAvailable);
      });
    });

    test('should expose currentVersion', () {
      final useCase = UpdateUseCase(
        updateRepo: mockRepository,
        apkRepo: mockApkRepo,
        currentVersion: '2.5.3',
      );

      expect(useCase.currentVersion, '2.5.3');
    });

    group('version robustness', () {
      test('should treat pre-release suffix as base version', () async {
        final useCase = UpdateUseCase(
          updateRepo: mockRepository,
          apkRepo: mockApkRepo,
          currentVersion: '1.0.0',
        );
        const release = AppRelease(
          version: '1.2.0-beta',
          htmlUrl: 'https://example.com',
        );
        when(
          () => mockRepository.getLatestRelease(),
        ).thenAnswer((_) async => release);

        final result = await useCase.checkForUpdate();

        result.fold(
          (_) => fail('Should be Right'),
          (status) => expect(status.isUpdateAvailable, true),
        );
      });

      test('should treat build metadata as base version', () async {
        final useCase = UpdateUseCase(
          updateRepo: mockRepository,
          apkRepo: mockApkRepo,
          currentVersion: '1.2.0',
        );
        const release = AppRelease(
          version: '1.2.0+5',
          htmlUrl: 'https://example.com',
        );
        when(
          () => mockRepository.getLatestRelease(),
        ).thenAnswer((_) async => release);

        final result = await useCase.checkForUpdate();

        result.fold(
          (_) => fail('Should be Right'),
          (status) => expect(status.isUpdateAvailable, false),
        );
      });

      test('should handle uppercase V prefix', () async {
        final useCase = UpdateUseCase(
          updateRepo: mockRepository,
          apkRepo: mockApkRepo,
          currentVersion: '1.0.0',
        );
        const release = AppRelease(
          version: 'V1.2.0',
          htmlUrl: 'https://example.com',
        );
        when(
          () => mockRepository.getLatestRelease(),
        ).thenAnswer((_) async => release);

        final result = await useCase.checkForUpdate();

        result.fold(
          (_) => fail('Should be Right'),
          (status) => expect(status.isUpdateAvailable, true),
        );
      });

      test('should return UpdateFailure when version is unparsable', () async {
        final useCase = UpdateUseCase(
          updateRepo: mockRepository,
          apkRepo: mockApkRepo,
          currentVersion: '1.0.0',
        );
        const release = AppRelease(
          version: 'not-a-version',
          htmlUrl: 'https://example.com',
        );
        when(
          () => mockRepository.getLatestRelease(),
        ).thenAnswer((_) async => release);

        final result = await useCase.checkForUpdate();

        expect(result.isLeft(), true);
        result.fold(
          (f) => expect(f, isA<UpdateFailure>()),
          (_) => fail('Should be Left'),
        );
      });
    });
  });
}
