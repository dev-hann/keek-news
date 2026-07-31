import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/content_scan_result.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/merged_feed.dart';
import 'package:keek_news/repository/community_repo.dart';
import 'package:keek_news/repository/dogdrip/dogdrip_impl.dart';
import 'package:keek_news/repository/humoruniv/humoruniv_impl.dart';
import 'package:keek_news/repository/ppomppu/ppomppu_impl.dart';
import 'package:keek_news/repository/todayhumor/todayhumor_impl.dart';
import 'package:keek_news/service/html_service.dart';
import 'package:keek_news/use_case/get_merged_feed_use_case.dart';

class FixtureHtmlService implements HtmlService {
  FixtureHtmlService(this._fixtures);
  final Map<String, String> _fixtures;

  @override
  Future<String> get(String path) async {
    for (final entry in _fixtures.entries) {
      if (path.contains(entry.key)) return entry.value;
    }
    throw Exception('No fixture for: $path');
  }

  @override
  int extractNumber(String? text) {
    if (text == null) return 0;
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  @override
  String textOf(Element? element) => element?.text.trim() ?? '';

  @override
  String? attrOf(Element? element, String name) => element?.attributes[name];

  @override
  int statOf(Element? parent, String selector) {
    if (parent == null) return 0;
    return extractNumber(textOf(parent.querySelector(selector)));
  }

  @override
  DateTime? parseDate(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return DateTime.tryParse(trimmed);
  }

  @override
  ContentScanResult scanContent(Element container) =>
      const ContentScanResult(blocks: [], imageUrls: []);

  @override
  ContentScanResult scanContentFull(Document doc, Element contentEl) =>
      const ContentScanResult(blocks: [], imageUrls: []);

  @override
  List<ContentBlock> scanContentCompact(Element container) => const [];
}

String _readFixture(String path) =>
    File('test/fixtures/$path').readAsStringSync();

void main() {
  late GetMergedFeedUseCase useCase;

  setUpAll(() {
    final repos = <CommunityId, CommunityRepo>{
      CommunityId.humoruniv: HumorunivImpl(
        htmlClient: FixtureHtmlService({
          'board/list.html': _readFixture('board_list_pds.html'),
          'board/read.html': _readFixture('pds_1415455.html'),
        }),
      ),
      CommunityId.todayhumor: TodayhumorImpl(
        htmlClient: FixtureHtmlService({
          'list.php?table=humorbest': _readFixture(
            'todayhumor/list_humorbest_pc.html',
          ),
          'view.php': _readFixture('todayhumor/detail_483503.html'),
        }),
      ),
      CommunityId.ppomppu: PpomppuImpl(
        htmlClient: FixtureHtmlService({
          'zboard.php?id=humor': _readFixture('ppomppu/list_humor.html'),
          'view.php': _readFixture('ppomppu/detail_770409.html'),
        }),
      ),
      CommunityId.dogdrip: DogdripImpl(
        htmlClient: FixtureHtmlService({
          'mid=dogdrip': _readFixture('dogdrip/list_dogdrip.html'),
        }),
      ),
    };

    useCase = GetMergedFeedUseCase(repos: repos);
  });

  group('Merged feed integration (real repos + fixture HTML)', () {
    test('should return items from multiple communities', () async {
      final result = await useCase(const MergedFeedParams(perSource: 20));

      expect(result.isRight(), isTrue);
      final page = result.getOrElse(() => throw StateError(''));
      expect(page.items, isNotEmpty);

      final communities = page.items.map((e) => e.community).toSet();
      expect(communities.length, greaterThan(1));
      expect(
        communities,
        contains(CommunityId.todayhumor),
        reason: 'todayhumor repo must contribute items (humorbest board)',
      );
    });

    test('should sort by publishedAt descending', () async {
      final result = await useCase(const MergedFeedParams(perSource: 20));

      final page = result.getOrElse(() => throw StateError(''));
      final ts = page.items
          .where((e) => e.publishedAt != null)
          .map((e) => e.publishedAt!.millisecondsSinceEpoch)
          .toList();

      for (var i = 1; i < ts.length; i++) {
        expect(ts[i - 1], greaterThanOrEqualTo(ts[i]));
      }
    });

    test('should return items with titles and URLs', () async {
      final result = await useCase(const MergedFeedParams(perSource: 20));

      final page = result.getOrElse(() => throw StateError(''));
      for (final item in page.items) {
        expect(item.title, isNotEmpty);
        expect(item.url, isNotEmpty);
        expect(item.id, isNotEmpty);
      }
    });

    test('should have cursor for pagination', () async {
      final result = await useCase(const MergedFeedParams(perSource: 20));

      final page = result.getOrElse(() => throw StateError(''));
      if (page.items.isNotEmpty) {
        expect(page.next, isNotNull);
      }
    });

    test('should filter by enabled communities', () async {
      final result = await useCase(
        const MergedFeedParams(perSource: 20, enabled: {CommunityId.humoruniv}),
      );

      final page = result.getOrElse(() => throw StateError(''));
      for (final item in page.items) {
        expect(item.community, CommunityId.humoruniv);
      }
    });

    test('should isolate failing repos', () async {
      final failingUseCase = GetMergedFeedUseCase(
        repos: {
          CommunityId.humoruniv: HumorunivImpl(
            htmlClient: FixtureHtmlService({}),
          ),
          CommunityId.todayhumor: TodayhumorImpl(
            htmlClient: FixtureHtmlService({
              'list.php': _readFixture('todayhumor/list_humorbest_pc.html'),
            }),
          ),
        },
      );

      final result = await failingUseCase(
        const MergedFeedParams(perSource: 20),
      );
      expect(result.isRight(), isTrue);

      final page = result.getOrElse(() => throw StateError(''));
      expect(page.failedSources, contains(CommunityId.humoruniv));
      expect(
        page.items.every((e) => e.community != CommunityId.humoruniv),
        isTrue,
      );
    });
  });
}
