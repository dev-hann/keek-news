import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/domain/entities/app_release.dart';
import 'package:happy_news/domain/entities/update_check_result.dart';

void main() {
  group('UpdateCheckResult', () {
    test('should store type and release', () {
      const release = AppRelease(
        version: '1.2.0',
        htmlUrl: 'https://example.com',
      );
      const result = UpdateCheckResult(
        type: UpdateStatusType.updateAvailable,
        release: release,
      );

      expect(result.type, UpdateStatusType.updateAvailable);
      expect(result.release.version, '1.2.0');
    });

    test('isUpdateAvailable returns true when type is updateAvailable', () {
      const release = AppRelease(
        version: '1.2.0',
        htmlUrl: 'https://example.com',
      );
      const result = UpdateCheckResult(
        type: UpdateStatusType.updateAvailable,
        release: release,
      );

      expect(result.isUpdateAvailable, true);
    });

    test('isUpdateAvailable returns false when type is upToDate', () {
      const release = AppRelease(
        version: '1.0.0',
        htmlUrl: 'https://example.com',
      );
      const result = UpdateCheckResult(
        type: UpdateStatusType.upToDate,
        release: release,
      );

      expect(result.isUpdateAvailable, false);
    });

    test('should preserve release fields through result', () {
      const release = AppRelease(
        version: '2.0.0',
        htmlUrl: 'https://example.com/v2',
        downloadUrl: 'https://example.com/app.apk',
        releaseNotes: 'New features',
      );
      const result = UpdateCheckResult(
        type: UpdateStatusType.updateAvailable,
        release: release,
      );

      expect(result.release.htmlUrl, 'https://example.com/v2');
      expect(result.release.downloadUrl, 'https://example.com/app.apk');
      expect(result.release.releaseNotes, 'New features');
    });
  });
}
