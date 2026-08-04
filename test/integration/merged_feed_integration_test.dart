import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/content_scan_result.dart';
import 'package:keek_news/repository/community/community_repo.dart';
import 'package:keek_news/repository/community/dogdrip/dogdrip_impl.dart';
import 'package:keek_news/repository/community/humoruniv/humoruniv_impl.dart';
import 'package:keek_news/repository/community/ppomppu/ppomppu_impl.dart';
import 'package:keek_news/repository/community/todayhumor/todayhumor_impl.dart';
import 'package:keek_news/repository/feed/feed_impl.dart';
import 'package:keek_news/repository/feed/feed_repo.dart';
import 'package:keek_news/service/html_service.dart';
import 'package:keek_news/service/prefs_local_storage_service.dart';
import 'package:keek_news/use_case/feed_use_case.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/html_service_helpers.dart';

class FixtureHtmlService extends HtmlService
    with HtmlServiceMultiCandidateMixin {
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
    final digits = text.replaceAll(RegExp('[^0-9]'), '');
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
  ContentScanResult scanContent(Element container) =>
      const ContentScanResult(blocks: [], imageUrls: []);

  @override
  ContentScanResult scanContentFull(Document doc, Element contentEl) =>
      const ContentScanResult(blocks: [], imageUrls: []);

  @override
  List<ContentBlock> scanContentCompact(Element container) => const [];
}

class _HumorunivOnlyFeedRepo implements FeedRepo {
  const _HumorunivOnlyFeedRepo();

  @override
  Set<CommunityId> getEnabledCommunities() => const {CommunityId.humoruniv};

  @override
  bool canDisable(CommunityId id) => false;

  @override
  void toggleCommunity(CommunityId id) {}
}

String _readFixture(String path) =>
    File('test/fixtures/$path').readAsStringSync();

void main() {
  late Map<CommunityId, CommunityRepo> repos;
  late FeedRepo feedRepo;
  late FeedUseCase useCase;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    feedRepo = FeedImpl(PrefsLocalStorageService(prefs));

    repos = <CommunityId, CommunityRepo>{
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

    useCase = FeedUseCase(repos: repos, feedRepo: feedRepo);
  });

  group('Merged feed integration (real repos + fixture HTML)', () {
    test('should return items from multiple communities', () async {
      final result = await useCase.getMergedFeed(const MergedFeedParams());

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
      final result = await useCase.getMergedFeed(const MergedFeedParams());

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
      final result = await useCase.getMergedFeed(const MergedFeedParams());

      final page = result.getOrElse(() => throw StateError(''));
      for (final item in page.items) {
        expect(item.title, isNotEmpty);
        expect(item.url, isNotEmpty);
        expect(item.id, isNotEmpty);
      }
    });

    test('should have cursor for pagination', () async {
      final result = await useCase.getMergedFeed(const MergedFeedParams());

      final page = result.getOrElse(() => throw StateError(''));
      if (page.items.isNotEmpty) {
        expect(page.next, isNotNull);
      }
    });

    test('should filter by enabled communities', () async {
      final filteredUseCase = FeedUseCase(
        repos: repos,
        feedRepo: const _HumorunivOnlyFeedRepo(),
      );
      final result = await filteredUseCase.getMergedFeed(
        const MergedFeedParams(),
      );

      final page = result.getOrElse(() => throw StateError(''));
      for (final item in page.items) {
        expect(item.community, CommunityId.humoruniv);
      }
    });

    test('should isolate failing repos', () async {
      final failingUseCase = FeedUseCase(
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
        feedRepo: feedRepo,
      );

      final result = await failingUseCase.getMergedFeed(
        const MergedFeedParams(),
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
