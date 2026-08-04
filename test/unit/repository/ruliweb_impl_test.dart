import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/content_scan_result.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/repository/community/ruliweb/ruliweb_impl.dart';
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

RuliwebImpl _repo() => RuliwebImpl(
  htmlClient: _FixtureHtmlService({
    'best/humor': _read('ruliweb/list_page1.html'),
  }),
);

void main() {
  group('RuliwebImpl list parsing', () {
    test('should parse feed items from list page', () async {
      final repo = _repo();
      final result = await repo.fetchLatest();

      expect(result.items, isNotEmpty);
      final first = result.items.first;
      expect(first.community, CommunityId.ruliweb);
      expect(first.id, isNotEmpty);
      expect(first.title, isNotEmpty);
    });

    test('all items should have valid community id', () async {
      final repo = _repo();
      final result = await repo.fetchLatest();

      for (final item in result.items) {
        expect(item.community, CommunityId.ruliweb);
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

  group('RuliwebImpl.fetchDetail', () {
    const id = '76193577';

    RuliwebImpl detailRepo() => RuliwebImpl(
      htmlClient: _FixtureHtmlService({id: _read('ruliweb/detail.html')}),
    );

    test('returns detail with correct community and id', () async {
      final detail = await detailRepo().fetchDetail(id);

      expect(detail, isA<LoadedPostDetail>());
      expect(detail.community, CommunityId.ruliweb);
      expect(detail.id, int.parse(id));
    });

    test('parses non-empty title', () async {
      final detail = await detailRepo().fetchDetail(id);

      expect(detail.title, contains('아이템매니아'));
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

    test('parses recommend and view counts (regression)', () async {
      // Old selector `.btn_like` matched the first comment's like button
      // (document order) instead of the article header recommend, returning a
      // per-comment number. Live header exposes <span class="like">N</span>.
      // View count lives in <span class="hit hit_high">N</span>.
      final detail = await detailRepo().fetchDetail(id);

      expect(
        detail.viewCount,
        greaterThan(0),
        reason: '.hit should yield a positive view count',
      );
    });

    test(
      'recommend count comes from the article header, not a comment',
      () async {
        // Regression: `.btn_like` grabbed the first comment like (114). The
        // article header recommend for this fixture is 55
        // (`<span class="like">`).
        final detail = await detailRepo().fetchDetail(id);

        expect(detail.recommendCount, 55);
      },
    );

    test('comment count is parsed from the comment_count badge', () async {
      final detail = await detailRepo().fetchDetail(id);

      expect(detail.commentCount, greaterThan(0));
    });

    test('comments dedup and best-flag work (regression)', () async {
      // Old parser returned 0 comments (.comment_item / .cmt_row don't match).
      // Live markup uses div.comment and best + normal lists mirror each other.
      final detail = await detailRepo().fetchDetail(id);

      expect(
        detail.comments,
        isNotEmpty,
        reason: '.comment selector should yield items',
      );
      // No duplicate text contents.
      final texts = detail.comments.map((c) => c.content).toList();
      expect(
        texts.toSet().length,
        texts.length,
        reason: 'best list mirrors normal — dedup by content required',
      );
    });
  });
}
