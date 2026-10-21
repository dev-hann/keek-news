import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/blocked_image.dart';

void main() {
  group('BlockedImage', () {
    test('should round-trip through JSON', () {
      final image = BlockedImage(
        url: 'https://example.com/a.jpg',
        blockedAt: DateTime.fromMillisecondsSinceEpoch(1722324000000),
      );

      final decoded = BlockedImage.fromJson(image.toJson());

      expect(decoded.url, image.url);
      expect(decoded.blockedAt, image.blockedAt);
    });

    test('should use url in equality', () {
      final blockedAt = DateTime.fromMillisecondsSinceEpoch(1722324000000);
      expect(
        BlockedImage(url: 'https://x/a.jpg', blockedAt: blockedAt),
        BlockedImage(url: 'https://x/a.jpg', blockedAt: blockedAt),
      );
      expect(
        BlockedImage(url: 'https://x/a.jpg', blockedAt: blockedAt),
        isNot(BlockedImage(url: 'https://x/b.jpg', blockedAt: blockedAt)),
      );
    });
  });
}
