import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/content_scan_result.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/repository/ppomppu/ppomppu_impl.dart';
import 'package:keek_news/service/html_service.dart';

import '../../helpers/either_helper.dart';

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
  ContentScanResult scanContent(Element container) =>
      const ContentScanResult(blocks: [], imageUrls: []);

  @override
  ContentScanResult scanContentFull(Document doc, Element contentEl) =>
      const ContentScanResult(blocks: [], imageUrls: []);

  @override
  List<ContentBlock> scanContentCompact(Element container) => const [];
}

String _read(String path) => File('test/fixtures/$path').readAsStringSync();

PpomppuImpl _repo(String id, String fixtureFile) => PpomppuImpl(
  htmlClient: _FixtureHtmlService({id: _read('ppomppu/$fixtureFile.html')}),
);

Future<PostDetail> _detail(String id, String fixtureFile) async {
  final either = await _repo(id, fixtureFile).fetchDetail(id);
  return unwrapRight(either);
}

void main() {
  group('PpomppuImpl.fetchDetail media', () {
    test(
      'duplicate CDN-mirror <source> tags collapse to one VideoBlock',
      () async {
        final detail = await _detail('770512', 'detail_video_770512');

        final videos = detail.contentBlocks.whereType<VideoBlock>().toList();
        expect(videos, hasLength(1));
        expect(videos.single.url, contains('.mp4'));
      },
    );

    test('UI asset images are excluded from imageUrls', () async {
      final detail = await _detail('770409', 'detail_770409');

      expect(detail.imageUrls, isNotEmpty);
      for (final url in detail.imageUrls) {
        expect(url.toLowerCase(), isNot(contains('/images/')));
        expect(url.toLowerCase(), isNot(contains('/skin/')));
      }
      expect(
        detail.imageUrls.every((u) => u.contains('/zboard/data')),
        isTrue,
        reason: 'all content images should be under /zboard/data',
      );
    });

    test('UI asset images are excluded from contentBlocks', () async {
      final detail = await _detail('770409', 'detail_770409');

      final imgs = detail.contentBlocks.whereType<ImageBlock>().toList();
      expect(imgs, isNotEmpty);
      for (final b in imgs) {
        expect(b.url.toLowerCase(), isNot(contains('/images/')));
        expect(b.url.toLowerCase(), isNot(contains('/skin/')));
      }
    });
  });
}
