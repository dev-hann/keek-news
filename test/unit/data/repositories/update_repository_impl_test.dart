import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/errors/failures.dart';
import 'package:happy_news/data/datasources/github_remote_ds.dart';
import 'package:happy_news/data/repositories/update_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockGitHubRemoteDs extends Mock implements GitHubRemoteDs {}

void main() {
  late MockGitHubRemoteDs mockRemoteDs;
  late UpdateRepositoryImpl repository;

  const validJson = '''
  {
    "tag_name": "v1.2.0",
    "html_url": "https://github.com/dev-hann/humoruniv/releases/tag/v1.2.0",
    "body": "Release notes",
    "assets": [
      {
        "name": "app-release.apk",
        "browser_download_url": "https://github.com/dev-hann/humoruniv/releases/download/v1.2.0/app-release.apk"
      }
    ]
  }
  ''';

  setUp(() {
    mockRemoteDs = MockGitHubRemoteDs();
    repository = UpdateRepositoryImpl(remoteDs: mockRemoteDs);
  });

  group('UpdateRepositoryImpl', () {
    test('should return AppRelease when API returns valid JSON', () async {
      when(
        () => mockRemoteDs.fetchLatestRelease(),
      ).thenAnswer((_) async => validJson);

      final result = await repository.getLatestRelease();

      expect(result.isRight(), true);
      result.fold((_) => fail('Should be Right'), (release) {
        expect(release.version, '1.2.0');
        expect(release.htmlUrl, contains('v1.2.0'));
        expect(release.downloadUrl, contains('.apk'));
      });
    });

    test('should return UpdateFailure when API throws', () async {
      when(
        () => mockRemoteDs.fetchLatestRelease(),
      ).thenThrow(Exception('Network error'));

      final result = await repository.getLatestRelease();

      expect(result.isLeft(), true);
      result.fold((failure) {
        expect(failure, isA<UpdateFailure>());
      }, (_) => fail('Should be Left'));
    });

    test('should return UpdateFailure when parser returns null', () async {
      when(
        () => mockRemoteDs.fetchLatestRelease(),
      ).thenAnswer((_) async => '{"tag_name": ""}');

      final result = await repository.getLatestRelease();

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<UpdateFailure>()),
        (_) => fail('Should be Left'),
      );
    });

    test(
      'should return AppRelease without downloadUrl when no apk asset',
      () async {
        const noApkJson = '''
      {
        "tag_name": "v2.0.0",
        "html_url": "https://github.com/dev-hann/humoruniv/releases/tag/v2.0.0",
        "assets": []
      }
      ''';
        when(
          () => mockRemoteDs.fetchLatestRelease(),
        ).thenAnswer((_) async => noApkJson);

        final result = await repository.getLatestRelease();

        expect(result.isRight(), true);
        result.fold(
          (_) => fail('Should be Right'),
          (release) => expect(release.downloadUrl, isNull),
        );
      },
    );
  });
}
