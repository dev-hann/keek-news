import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/url_builder.dart';

void main() {
  group('UrlBuilder.resolveAbsolute', () {
    test(
      'should resolve humoruniv relative path to full m.humoruniv.com URL',
      () {
        final result = UrlBuilder.resolveAbsolute(
          CommunityId.humoruniv,
          '/board/read.html?table=pds&number=100',
        );

        expect(
          result,
          'https://m.humoruniv.com/board/read.html?table=pds&number=100',
        );
      },
    );

    test('should resolve todayhumor relative path to full URL', () {
      final result = UrlBuilder.resolveAbsolute(
        CommunityId.todayhumor,
        '/board/view.php?table=humorbest&no=12345',
      );

      expect(
        result,
        'https://www.todayhumor.co.kr/board/view.php?table=humorbest&no=12345',
      );
    });

    test('should resolve ppomppu relative path to full URL', () {
      final result = UrlBuilder.resolveAbsolute(
        CommunityId.ppomppu,
        '/zboard/view.php?id=humor&no=99',
      );

      expect(
        result,
        'https://www.ppomppu.co.kr/zboard/view.php?id=humor&no=99',
      );
    });

    test('should resolve dogdrip relative path to full URL', () {
      final result = UrlBuilder.resolveAbsolute(
        CommunityId.dogdrip,
        '/index.php?document_srl=716302509',
      );

      expect(
        result,
        'https://www.dogdrip.net/index.php?document_srl=716302509',
      );
    });

    test('should return input unchanged when already absolute http URL', () {
      const full = 'https://example.com/some/path';
      final result = UrlBuilder.resolveAbsolute(CommunityId.humoruniv, full);

      expect(result, full);
    });

    test('should return input unchanged when already absolute https URL', () {
      const full = 'https://m.humoruniv.com/board/read.html?table=pds&number=1';
      final result = UrlBuilder.resolveAbsolute(CommunityId.humoruniv, full);

      expect(result, full);
    });

    test('should preserve query parameters when resolving', () {
      final result = UrlBuilder.resolveAbsolute(
        CommunityId.humoruniv,
        '/board/read.html?table=pds&number=5&foo=bar',
      );

      expect(
        result,
        'https://m.humoruniv.com/board/read.html?table=pds&number=5&foo=bar',
      );
    });

    test('should resolve relative path without leading slash', () {
      final result = UrlBuilder.resolveAbsolute(
        CommunityId.humoruniv,
        'board/read.html?table=pds&number=1',
      );

      expect(
        result,
        'https://m.humoruniv.com/board/read.html?table=pds&number=1',
      );
    });
  });
}
