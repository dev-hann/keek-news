import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/content_scan_result.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/repository/community/natepann/natepann_impl.dart';
import 'package:keek_news/service/html_service.dart';
import '../../helpers/html_service_helpers.dart';

class _FixtureHtmlService extends HtmlService
    with HtmlServiceMultiCandidateMixin {
  _FixtureHtmlService(this._fixtures);
  final Map<String, String> _fixtures;

  @override
  Future<String> get(String path) async {
    for (final entry in _fixtures.entries) {
      if (path.contains(entry.key)) return entry.value;
    }
    throw Exception('No fixture for: $path');
  }

  @override
  String textOf(Element? element) => element?.text.trim() ?? '';

  @override
  String? attrOf(Element? element, String name) => element?.attributes[name];

  @override
  int extractNumber(String? text) {
    if (text == null) return 0;
    final digits = text.replaceAll(RegExp('[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

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

String _read(String path) => File('test/fixtures/$path').readAsStringSync();

NatepannImpl _repo() => NatepannImpl(
  htmlClient: _FixtureHtmlService({'/talk': _read('natepann/list_page1.html')}),
);

void main() {
  group('NatepannImpl list parsing', () {
    test('should parse feed items from list page', () async {
      final repo = _repo();
      final result = await repo.fetchLatest();

      expect(result.items, isNotEmpty);
      final first = result.items.first;
      expect(first.community, CommunityId.natepann);
      expect(first.id, isNotEmpty);
      expect(first.title, isNotEmpty);
    });

    test('all items should have valid community id', () async {
      final repo = _repo();
      final result = await repo.fetchLatest();

      for (final item in result.items) {
        expect(item.community, CommunityId.natepann);
      }
    });

    test('items should not have empty ids', () async {
      final repo = _repo();
      final result = await repo.fetchLatest();

      for (final item in result.items) {
        expect(item.id, isNotEmpty);
      }
    });
  });

  group('NatepannImpl.fetchDetail', () {
    const id = '375541390';

    NatepannImpl detailRepo() => NatepannImpl(
      htmlClient: _FixtureHtmlService({id: _read('natepann/detail.html')}),
    );

    test('returns detail with correct community and id', () async {
      final detail = await detailRepo().fetchDetail(id);

      expect(detail, isA<LoadedPostDetail>());
      expect(detail.community, CommunityId.natepann);
      expect(detail.id, int.parse(id));
    });

    test('parses non-empty title', () async {
      final detail = await detailRepo().fetchDetail(id);

      expect(detail.title, contains('컨포도'));
    });

    test('extracts author when present', () async {
      final detail = await detailRepo().fetchDetail(id);

      expect(detail.author, isNotEmpty);
    });

    test('parses content blocks or image urls', () async {
      final detail = await detailRepo().fetchDetail(id);

      expect(
        detail.contentBlocks.isNotEmpty || detail.imageUrls.isNotEmpty,
        isTrue,
        reason: 'detail page should yield content or images',
      );
      expect(detail.looksEmpty, isFalse);
    });

    test(
      'content blocks include text from the editor body (regression)',
      () async {
        // Old selector `.espresso_editor_view` (class) never matched — the
        // wrapper has id, not class — so the parser fell back to #contentArea
        // whose single child div was treated as one image cluster, dropping
        // every TextBlock. Assert text survives so this does not regress.
        final detail = await detailRepo().fetchDetail(id);

        final textBlocks = detail.contentBlocks.whereType<TextBlock>().toList();
        expect(
          textBlocks,
          isNotEmpty,
          reason: 'editor body should yield interleaved text blocks',
        );
        expect(textBlocks.any((b) => b.text.contains('라이즈')), isTrue);
      },
    );

    test('extracts comments (regression: old selector matched 0)', () async {
      // Fixture has 2 best + 2 normal comments rendered as dl.cmt_item. Old
      // selector (.cmt_post/.comment_item/li.comment) hit none of them.
      final detail = await detailRepo().fetchDetail(id);

      expect(
        detail.comments,
        hasLength(2),
        reason:
            'best and normal lists mirror the same two comments; '
            'dedup by id should leave 2',
      );
      expect(detail.comments.any((c) => c.content.contains('비주얼')), isTrue);
      expect(detail.comments.any((c) => c.content.contains('인외같다는')), isTrue);
      expect(detail.comments.any((c) => c.isBest), isTrue);
      expect(detail.comments.any((c) => c.recommendCount > 0), isTrue);
    });

    test('parses post stats from labeled .count spans (regression)', () async {
      // Old selectors (.reco_num/.good_count/.read_num/.view_count/.cmt_count)
      // matched nothing — recommend/view/commentCount all returned 0. Live
      // markup renders stats as sibling <span class="count"> elements whose
      // inner label (.tit or <em>) distinguishes them: 조회 2,086 / 추천수 6 /
      // 반대수 4. commentCount is derived from the parsed comment list.
      final detail = await detailRepo().fetchDetail(id);

      expect(detail.viewCount, 2086);
      expect(detail.recommendCount, 6);
      expect(detail.notRecommendCount, 4);
      expect(detail.commentCount, detail.comments.length);
    });
  });
}
