import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/app_release.dart';

void main() {
  group('AppRelease', () {
    test('should create with required fields', () {
      const release = AppRelease(
        version: '1.2.0',
        htmlUrl: 'https://github.com/dev-hann/humoruniv/releases/tag/v1.2.0',
      );

      expect(release.version, '1.2.0');
      expect(
        release.htmlUrl,
        'https://github.com/dev-hann/humoruniv/releases/tag/v1.2.0',
      );
      expect(release.downloadUrl, isNull);
      expect(release.releaseNotes, isNull);
    });

    test('should create with all fields', () {
      const release = AppRelease(
        version: '1.2.0',
        htmlUrl: 'https://github.com/dev-hann/humoruniv/releases/tag/v1.2.0',
        downloadUrl:
            'https://github.com/dev-hann/humoruniv/releases/download/v1.2.0/app-release.apk',
        releaseNotes: '버그 수정 및 성능 개선',
      );

      expect(release.version, '1.2.0');
      expect(release.downloadUrl, isNotNull);
      expect(release.releaseNotes, '버그 수정 및 성능 개선');
    });

    test('should support value equality when all fields match', () {
      const a = AppRelease(
        version: '1.0.0',
        htmlUrl: 'https://example.com',
        downloadUrl: 'https://example.com/file.apk',
        releaseNotes: 'notes',
      );
      const b = AppRelease(
        version: '1.0.0',
        htmlUrl: 'https://example.com',
        downloadUrl: 'https://example.com/file.apk',
        releaseNotes: 'notes',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('should not be equal when version differs', () {
      const a = AppRelease(version: '1.0.0', htmlUrl: 'https://example.com');
      const b = AppRelease(version: '1.0.1', htmlUrl: 'https://example.com');

      expect(a, isNot(equals(b)));
    });

    test('should not be equal when htmlUrl differs', () {
      const a = AppRelease(version: '1.0.0', htmlUrl: 'https://a.com');
      const b = AppRelease(version: '1.0.0', htmlUrl: 'https://b.com');

      expect(a, isNot(equals(b)));
    });

    test('should not be equal when downloadUrl differs', () {
      const a = AppRelease(
        version: '1.0.0',
        htmlUrl: 'https://example.com',
        downloadUrl: 'https://example.com/a.apk',
      );
      const b = AppRelease(
        version: '1.0.0',
        htmlUrl: 'https://example.com',
        downloadUrl: 'https://example.com/b.apk',
      );

      expect(a, isNot(equals(b)));
    });

    test('should not be equal when releaseNotes differs', () {
      const a = AppRelease(
        version: '1.0.0',
        htmlUrl: 'https://example.com',
        releaseNotes: 'a',
      );
      const b = AppRelease(
        version: '1.0.0',
        htmlUrl: 'https://example.com',
        releaseNotes: 'b',
      );

      expect(a, isNot(equals(b)));
    });

    test('should not be equal to non-AppRelease object', () {
      const a = AppRelease(version: '1.0.0', htmlUrl: 'https://example.com');

      expect(a, isNot(equals('not a release')));
      expect(a, isNot(equals(42)));
    });

    test('should be equal to itself (identical)', () {
      const a = AppRelease(version: '1.0.0', htmlUrl: 'https://example.com');

      expect(a, equals(a));
    });
  });

  group('AppRelease.fromJson', () {
    test('should strip v prefix from tag_name', () {
      final release = AppRelease.fromJson({
        'tag_name': 'v1.2.3',
        'html_url': 'https://github.com/x/y/releases/tag/v1.2.3',
      });

      expect(release.version, '1.2.3');
      expect(release.htmlUrl, 'https://github.com/x/y/releases/tag/v1.2.3');
    });

    test('should extract apk asset browser_download_url', () {
      final release = AppRelease.fromJson({
        'tag_name': '1.0.0',
        'html_url': 'https://example.com',
        'assets': [
          {
            'name': 'app-release.apk',
            'browser_download_url': 'https://dl/a.apk',
          },
          {'name': 'checksum.txt', 'browser_download_url': 'https://dl/c.txt'},
        ],
      });

      expect(release.downloadUrl, 'https://dl/a.apk');
    });

    test('should set releaseNotes from body when non-empty', () {
      final release = AppRelease.fromJson({
        'tag_name': '1.0.0',
        'html_url': 'https://example.com',
        'body': '변경 내역',
      });

      expect(release.releaseNotes, '변경 내역');
    });

    test('should null releaseNotes when body empty', () {
      final release = AppRelease.fromJson({
        'tag_name': '1.0.0',
        'html_url': 'https://example.com',
        'body': '',
      });

      expect(release.releaseNotes, isNull);
    });

    test('should default to empty version when tag_name missing', () {
      final release = AppRelease.fromJson({'html_url': 'https://x'});

      expect(release.version, isEmpty);
    });
  });
}
