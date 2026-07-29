import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/domain/entities/download_progress.dart';

void main() {
  group('DownloadProgress', () {
    test('should compute percent from received/total bytes', () {
      const progress = DownloadProgress(receivedBytes: 50, totalBytes: 200);

      expect(progress.percent, 25);
    });

    test('should round percent to nearest integer', () {
      const progress = DownloadProgress(receivedBytes: 1, totalBytes: 3);

      expect(progress.percent, 33);
    });

    test('should report 100 percent when fully downloaded', () {
      const progress = DownloadProgress(receivedBytes: 100, totalBytes: 100);

      expect(progress.percent, 100);
    });

    test('should clamp to 100 when received exceeds total', () {
      const progress = DownloadProgress(receivedBytes: 150, totalBytes: 100);

      expect(progress.percent, 100);
    });

    test('should report 0 percent at start', () {
      const progress = DownloadProgress(receivedBytes: 0, totalBytes: 100);

      expect(progress.percent, 0);
    });

    test('should report 0 percent when total size is unknown', () {
      const progress = DownloadProgress(receivedBytes: 500, totalBytes: -1);

      expect(progress.isUnknownSize, true);
      expect(progress.percent, 0);
    });

    test('should support value equality', () {
      const a = DownloadProgress(receivedBytes: 10, totalBytes: 100);
      const b = DownloadProgress(receivedBytes: 10, totalBytes: 100);
      const c = DownloadProgress(receivedBytes: 20, totalBytes: 100);

      expect(a, b);
      expect(a, isNot(c));
    });
  });
}
