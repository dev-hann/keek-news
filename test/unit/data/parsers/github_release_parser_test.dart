import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/data/parsers/github_release_parser.dart';

void main() {
  group('GitHubReleaseParser', () {
    test('should parse valid JSON with all fields', () {
      const json = '''
      {
        "tag_name": "v1.2.0",
        "html_url": "https://github.com/dev-hann/humoruniv/releases/tag/v1.2.0",
        "body": "버그 수정 및 성능 개선",
        "assets": [
          {
            "name": "app-release.apk",
            "browser_download_url": "https://github.com/dev-hann/humoruniv/releases/download/v1.2.0/app-release.apk"
          }
        ]
      }
      ''';

      final result = GitHubReleaseParser.parse(json);

      expect(result, isNotNull);
      expect(result!.version, '1.2.0');
      expect(
        result.htmlUrl,
        'https://github.com/dev-hann/humoruniv/releases/tag/v1.2.0',
      );
      expect(result.releaseNotes, '버그 수정 및 성능 개선');
      expect(
        result.downloadUrl,
        'https://github.com/dev-hann/humoruniv/releases/download/v1.2.0/app-release.apk',
      );
    });

    test('should return null when JSON is empty string', () {
      final result = GitHubReleaseParser.parse('');

      expect(result, isNull);
    });

    test('should return null when JSON is invalid', () {
      final result = GitHubReleaseParser.parse('not json at all');

      expect(result, isNull);
    });

    test('should return null when tag_name is missing', () {
      const json = '{"html_url": "https://example.com"}';

      final result = GitHubReleaseParser.parse(json);

      expect(result, isNull);
    });

    test('should return null when html_url is missing', () {
      const json = '{"tag_name": "v1.0.0"}';

      final result = GitHubReleaseParser.parse(json);

      expect(result, isNull);
    });

    test('should handle tag_name without v prefix', () {
      const json =
          '{"tag_name": "2.0.0", "html_url": "https://example.com", "assets": []}';

      final result = GitHubReleaseParser.parse(json);

      expect(result, isNotNull);
      expect(result!.version, '2.0.0');
    });

    test('should handle release without assets', () {
      const json = '''
      {
        "tag_name": "v1.1.0",
        "html_url": "https://example.com",
        "body": "notes",
        "assets": []
      }
      ''';

      final result = GitHubReleaseParser.parse(json);

      expect(result, isNotNull);
      expect(result!.version, '1.1.0');
      expect(result.downloadUrl, isNull);
    });

    test('should handle release without body', () {
      const json = '''
      {
        "tag_name": "v1.1.0",
        "html_url": "https://example.com",
        "assets": []
      }
      ''';

      final result = GitHubReleaseParser.parse(json);

      expect(result, isNotNull);
      expect(result!.releaseNotes, isNull);
    });

    test('should pick first apk asset when multiple assets exist', () {
      const json = '''
      {
        "tag_name": "v1.3.0",
        "html_url": "https://example.com",
        "assets": [
          {"name": "source.zip", "browser_download_url": "https://example.com/source.zip"},
          {"name": "app-arm64-v8a-release.apk", "browser_download_url": "https://example.com/arm64.apk"},
          {"name": "app-universal-release.apk", "browser_download_url": "https://example.com/universal.apk"}
        ]
      }
      ''';

      final result = GitHubReleaseParser.parse(json);

      expect(result, isNotNull);
      expect(result!.downloadUrl, 'https://example.com/arm64.apk');
    });

    test('should return null when tag_name is empty', () {
      const json =
          '{"tag_name": "", "html_url": "https://example.com", "assets": []}';

      final result = GitHubReleaseParser.parse(json);

      expect(result, isNull);
    });
  });
}
