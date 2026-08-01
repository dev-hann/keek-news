import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/content_scan_result.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/repository/dogdrip/dogdrip_impl.dart';
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

DogdripImpl _repo(String id, String fixtureFile) => DogdripImpl(
  htmlClient: _FixtureHtmlService({id: _read('dogdrip/$fixtureFile.html')}),
);

Future<PostDetail> _detail(String id, String fixtureFile) async {
  final either = await _repo(id, fixtureFile).fetchDetail(id);
  return unwrapRight(either);
}

void main() {
  group('DogdripImpl.fetchDetail content blocks', () {
    test(
      'bare direct-child <video> produces a VideoBlock (716669066)',
      () async {
        final detail = await _detail('716669066', 'detail_716669066');

        final videos = detail.contentBlocks.whereType<VideoBlock>().toList();
        expect(videos, hasLength(1));
        expect(videos.single.url, contains('.mp4'));
        expect(videos.single.thumbnailUrl, isNotNull);
      },
    );

    test(
      'center-wrapped <video><source> produces a VideoBlock (regression)',
      () async {
        final detail = await _detail('716302509', 'detail_716302509');

        expect(detail.contentBlocks.whereType<VideoBlock>(), hasLength(1));
      },
    );

    test('p-wrapped <img> still produces an ImageBlock (regression)', () async {
      final detail = await _detail('716024142', 'detail_716024142');

      expect(detail.contentBlocks.whereType<ImageBlock>(), isNotEmpty);
    });
  });

  group('DogdripImpl.fetchDetail comments', () {
    test('parses comment count from "N개의 댓글" (716616998)', () async {
      final detail = await _detail('716616998', 'detail_716616998');

      expect(detail.commentCount, 18);
    });

    test('extracts comments (716616998)', () async {
      final detail = await _detail('716616998', 'detail_716616998');

      expect(detail.comments, isNotEmpty);
      for (final c in detail.comments) {
        expect(c.author, isNotEmpty);
      }
    });

    test('bare video post also parses comment count (716669066)', () async {
      final detail = await _detail('716669066', 'detail_716669066');

      expect(detail.commentCount, greaterThanOrEqualTo(0));
    });
  });
}
