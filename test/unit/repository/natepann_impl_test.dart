import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/content_scan_result.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/repository/community/natepann/natepann_impl.dart';
import 'package:keek_news/service/html_service.dart';

class _FixtureHtmlService extends HtmlService {
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
    final match = RegExp(r'(\d+)').firstMatch(text);
    return match != null ? int.parse(match.group(1)!) : 0;
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

      expect(detail.title, isNotEmpty);
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
  });
}
