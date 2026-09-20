import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/service/community_headers.dart';

void main() {
  group('mediaDownloadHeaders', () {
    test('humoruniv gets mobile UA and Referer', () {
      final headers = mediaDownloadHeaders(
        'https://m.humoruniv.com/board/pds/img/123.jpg',
      );
      expect(headers['User-Agent'], mobileUserAgent);
      expect(headers['Referer'], 'https://m.humoruniv.com/board/pds/');
    });

    test('dogdrip gets desktop UA and Referer (hotlink protection)', () {
      final headers = mediaDownloadHeaders(
        'https://www.dogdrip.net/files/attach/images/300/a.png',
      );
      expect(headers['User-Agent'], desktopUserAgent);
      expect(
        headers['Referer'],
        'https://www.dogdrip.net/index.php?mid=dogdrip',
      );
    });

    test('fmkorea gets Referer', () {
      final headers = mediaDownloadHeaders(
        'https://www.fmkorea.com/files/attach/x.gif',
      );
      expect(headers['Referer'], 'https://www.fmkorea.com/index.php?mid=humor');
    });

    test('ruliweb gets Referer', () {
      final headers = mediaDownloadHeaders(
        'https://bbs.ruliweb.com/img/a.webp',
      );
      expect(headers['Referer'], 'https://bbs.ruliweb.com/best/humor');
    });

    test('natepann gets Referer', () {
      final headers = mediaDownloadHeaders('https://pann.nate.com/img/a.jpg');
      expect(headers['Referer'], 'https://pann.nate.com/talk');
    });

    test('unknown host gets desktop UA and no Referer', () {
      final headers = mediaDownloadHeaders('https://cdn.example.com/a.jpg');
      expect(headers['User-Agent'], desktopUserAgent);
      expect(headers.containsKey('Referer'), isFalse);
    });

    test('unparseable url falls back to desktop UA', () {
      final headers = mediaDownloadHeaders('not-a-url');
      expect(headers['User-Agent'], desktopUserAgent);
      expect(headers.containsKey('Referer'), isFalse);
    });

    test('host match is case-insensitive', () {
      final headers = mediaDownloadHeaders(
        'https://WWW.DOGDRIP.NET/files/a.png',
      );
      expect(
        headers['Referer'],
        'https://www.dogdrip.net/index.php?mid=dogdrip',
      );
    });

    test('browser headers are included for community hosts', () {
      final headers = mediaDownloadHeaders('https://m.humoruniv.com/a.jpg');
      expect(headers['Accept-Language'], browserHeaders['Accept-Language']);
    });
  });
}
