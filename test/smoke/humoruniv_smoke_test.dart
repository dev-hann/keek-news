import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/repository/community/community_repo.dart';
import 'package:keek_news/service/service_locator.dart' as di;
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/package_info_helper.dart';
import '../helpers/path_provider_helper.dart';
import 'helpers.dart';

final _hangul = RegExp(r'[\uAC00-\uD7A3]');

void main() {
  final skip = Platform.environment['SMOKE'] != '1';

  // Resolves the repo through `configureDependencies()` — the production
  // encoding, headers and cookie jar — instead of a hand-built client.
  // Fixtures are stored already decoded, so unit tests cannot see the
  // charset: humoruniv switched EUC-KR → UTF-8 in 2026-10 and the feed served
  // mojibake for weeks because nothing exercised this path against the site.
  group('Smoke: Humoruniv live fetch through production wiring', () {
    setUpAll(() async {
      ensureLiveNetwork();
      await setupPackageInfoMock();
      setupPathProviderMock();
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(di.sl.reset);

    test('list and detail decode Korean', () async {
      await di.configureDependencies();
      final repo = di
          .sl<Map<CommunityId, CommunityRepo>>()[CommunityId.humoruniv]!;

      final result = await repo.fetchLatest();

      expect(result.items, isNotEmpty, reason: 'humoruniv list is empty');
      expect(
        result.items.any((i) => _hangul.hasMatch(i.title)),
        isTrue,
        reason:
            'no decoded Korean title: '
            '${result.items.take(5).map((i) => i.title).toList()}',
      );

      final detail = await repo.fetchDetail(result.items.first.id);

      // `작성 YYYY-MM-DD` is server template text: it only survives a correct
      // decode, otherwise the date falls back to the epoch.
      expect(
        detail.date.year,
        greaterThan(2000),
        reason:
            'post date not decoded — charset drift? '
            'first title: "${result.items.first.title}"',
      );
      expect(detail.title, isNotEmpty);
      expect(detail.author, isNotEmpty);
    }, skip: skip);
  });
}
