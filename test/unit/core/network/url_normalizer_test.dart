import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/network/url_normalizer.dart';

void main() {
  group('UrlNormalizer', () {
    test('should return empty string for empty input', () {
      expect(UrlNormalizer.normalize(''), '');
    });

    test('should add https: prefix to protocol-relative URL', () {
      expect(
        UrlNormalizer.normalize('//down.humoruniv.com/img.jpg'),
        'https://down.humoruniv.com/img.jpg',
      );
    });

    test('should fix double slash after domain in https URL', () {
      expect(
        UrlNormalizer.normalize('https://down.humoruniv.com//path/img.jpg'),
        'https://down.humoruniv.com/path/img.jpg',
      );
    });

    test('should fix triple slash after domain', () {
      expect(
        UrlNormalizer.normalize('https://down.humoruniv.com///path/img.jpg'),
        'https://down.humoruniv.com/path/img.jpg',
      );
    });

    test('should handle protocol-relative URL with double slash', () {
      expect(
        UrlNormalizer.normalize('//down.humoruniv.com//path/img.jpg'),
        'https://down.humoruniv.com/path/img.jpg',
      );
    });

    test('should not modify already correct URL', () {
      const url = 'https://down.humoruniv.com/path/img.jpg';
      expect(UrlNormalizer.normalize(url), url);
    });

    test('should handle http URLs', () {
      expect(
        UrlNormalizer.normalize('http://example.com//path'),
        'http://example.com/path',
      );
    });

    test('should trim whitespace', () {
      expect(
        UrlNormalizer.normalize('  https://example.com/path  '),
        'https://example.com/path',
      );
    });
  });
}
