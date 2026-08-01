import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/app_release.dart';
import 'package:keek_news/repository/apk_install/apk_install_repo.dart';
import 'package:keek_news/repository/update/update_impl.dart';
import 'package:keek_news/repository/update/update_repo.dart';
import 'package:keek_news/service/github_remote_service.dart';
import 'package:keek_news/use_case/update_use_case.dart';
import 'package:mocktail/mocktail.dart';

class FixtureGitHubRemoteService implements GitHubRemoteService {
  FixtureGitHubRemoteService(this._fixturePath);
  final String _fixturePath;

  @override
  Future<String> fetchLatestRelease() async {
    return File(_fixturePath).readAsStringSync();
  }
}

class _MockApkInstallRepo extends Mock implements ApkInstallRepo {}

void main() {
  late UpdateRepo repository;
  late UpdateUseCase useCase;

  setUp(() {
    final remoteDs = FixtureGitHubRemoteService(
      'test/fixtures/github_release_latest.json',
    );
    repository = UpdateImpl(remoteDs: remoteDs);
    useCase = UpdateUseCase(
      updateRepo: repository,
      apkRepo: _MockApkInstallRepo(),
      currentVersion: '1.0.0',
    );
  });

  group('Integration: update flow', () {
    test('should parse real GitHub release JSON through full chain and '
        'detect available update', () async {
      final result = await useCase.checkForUpdate();

      expect(result.isRight(), true);
      result.fold((_) => fail('Should be Right'), (checkResult) {
        expect(checkResult.isUpdateAvailable, true);
        expect(checkResult.release.version, '1.5.0');
      });
    });

    test('should preserve download URL and release notes end-to-end', () async {
      final result = await useCase.checkForUpdate();

      result.fold((_) => fail('Should be Right'), (checkResult) {
        final release = checkResult.release;
        expect(release.downloadUrl, contains('.apk'));
        expect(release.downloadUrl, contains('v1.5.0'));
        expect(release.htmlUrl, contains('github.com'));
        expect(release.releaseNotes, isNotNull);
      });
    });

    test(
      'should report up-to-date when current version matches fixture',
      () async {
        final useCase = UpdateUseCase(
          updateRepo: repository,
          apkRepo: _MockApkInstallRepo(),
          currentVersion: '1.5.0',
        );

        final result = await useCase.checkForUpdate();

        result.fold((_) => fail('Should be Right'), (checkResult) {
          expect(checkResult.isUpdateAvailable, false);
        });
      },
    );

    test(
      'should return AppRelease with valid fields from repository',
      () async {
        final result = await repository.getLatestRelease();

        expect(result, isA<AppRelease>());
        expect(result.version, isNotEmpty);
        expect(result.htmlUrl, startsWith('https://'));
      },
    );
  });
}
