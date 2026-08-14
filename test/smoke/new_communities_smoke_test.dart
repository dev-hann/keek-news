import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/repository/community/bobaedream/bobaedream_impl.dart';
import 'package:keek_news/repository/community/fmkorea/fmkorea_impl.dart';
import 'package:keek_news/repository/community/natepann/natepann_impl.dart';
import 'package:keek_news/repository/community/ruliweb/ruliweb_impl.dart';
import 'package:keek_news/service/dio_html_service.dart';

const _userAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

const _browserHeaders = <String, String>{
  'Accept':
      'text/html,application/xhtml+xml,application/xml;q=0.9,'
      'image/avif,image/webp,*/*;q=0.8',
  'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
};

DioHtmlService _service(String baseUrl, String encoding) {
  return DioHtmlService(
    dio: Dio(
      BaseOptions(
        baseUrl: baseUrl,
        headers: {
          'User-Agent': _userAgent,
          ..._browserHeaders,
          'Referer': '$baseUrl/',
        },
        responseType: ResponseType.bytes,
      ),
    ),
    encoding: encoding,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = Platform.environment['SMOKE'] != '1';

  // fmkorea is currently hidden from the UI and feed (see
  // hiddenCommunityIds); its live fetch is blocked by the fmkorea WAF
  // (HTTP 430 "에펨코리아 보안 시스템"), so this smoke is force-skipped until
  // the community is re-enabled. Re-enable by dropping the skip override.
  group('Smoke: FMKorea live fetch', () {
    test('fetchLatest returns items and fetchDetail returns a title', () async {
      final repo = FmkoreaImpl(
        htmlClient: _service('https://www.fmkorea.com', 'utf-8'),
      );
      final result = await repo.fetchLatest();

      expect(
        result.items,
        isNotEmpty,
        reason: 'FMKorea list should not be empty',
      );

      final detail = await repo.fetchDetail(result.items.first.id);
      expect(detail.title, isNotEmpty, reason: 'FMKorea detail title empty');
    }, skip: 'fmkorea disabled (WAF 430); re-enable with the community');
  });

  group('Smoke: Bobaedream live fetch', () {
    test('fetchLatest returns items and fetchDetail returns a title', () async {
      final repo = BobaedreamImpl(
        htmlClient: _service('https://www.bobaedream.co.kr', 'utf-8'),
      );
      final result = await repo.fetchLatest();

      expect(
        result.items,
        isNotEmpty,
        reason: 'Bobaedream list should not be empty',
      );

      final detail = await repo.fetchDetail(result.items.first.id);
      expect(detail.title, isNotEmpty, reason: 'Bobaedream detail title empty');
    }, skip: skip);
  });

  group('Smoke: Ruliweb live fetch', () {
    test('fetchLatest returns items and fetchDetail returns a title', () async {
      final repo = RuliwebImpl(
        htmlClient: _service('https://bbs.ruliweb.com', 'utf-8'),
      );
      final result = await repo.fetchLatest();

      expect(result.items, isNotEmpty, reason: 'Ruliweb list not empty');

      final detail = await repo.fetchDetail(result.items.first.id);
      expect(detail.title, isNotEmpty, reason: 'Ruliweb title empty');
    }, skip: skip);
  });

  group('Smoke: Natepann live fetch', () {
    test('fetchLatest returns items and fetchDetail returns a title', () async {
      final repo = NatepannImpl(
        htmlClient: _service('https://pann.nate.com', 'utf-8'),
      );
      final result = await repo.fetchLatest();

      expect(
        result.items,
        isNotEmpty,
        reason: 'Natepann list should not be empty',
      );

      final detail = await repo.fetchDetail(result.items.first.id);
      expect(detail.title, isNotEmpty, reason: 'Natepann detail title empty');
    }, skip: skip);
  });
}
