import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/repository/update/update_impl.dart';
import 'package:keek_news/service/github_remote_service.dart';
import 'package:mocktail/mocktail.dart';

class MockGitHubRemoteService extends Mock implements GitHubRemoteService {}

void main() {
  late MockGitHubRemoteService mockRemoteDs;
  late UpdateImpl repository;

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
    mockRemoteDs = MockGitHubRemoteService();
    repository = UpdateImpl(remoteDs: mockRemoteDs);
  });

  group('UpdateImpl', () {
    test('should return AppRelease when API returns valid JSON', () async {
      when(
        () => mockRemoteDs.fetchLatestRelease(),
      ).thenAnswer((_) async => validJson);

      final result = await repository.getLatestRelease();

      expect(result.version, '1.2.0');
      expect(result.htmlUrl, contains('v1.2.0'));
      expect(result.downloadUrl, contains('.apk'));
    });

    test('should return UpdateFailure when API throws', () async {
      when(
        () => mockRemoteDs.fetchLatestRelease(),
      ).thenThrow(Exception('Network error'));

      expect(() => repository.getLatestRelease(), throwsA(isA<Exception>()));
    });

    test('should throw FormatException when parser returns null', () async {
      when(
        () => mockRemoteDs.fetchLatestRelease(),
      ).thenAnswer((_) async => '{"tag_name": ""}');

      expect(
        () => repository.getLatestRelease(),
        throwsA(isA<FormatException>()),
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

        expect(result.downloadUrl, isNull);
      },
    );
  });
}
