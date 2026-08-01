import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/content_scan_result.dart';
import 'package:keek_news/repository/todayhumor/todayhumor_impl.dart';
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

void main() {
  group('TodayhumorImpl.fetchDetail comments', () {
    test('parses AJAX comments, skips system/deleted, nests replies', () async {
      final repo = TodayhumorImpl(
        htmlClient: _FixtureHtmlService({
          'view.php': _read('todayhumor/detail_483503.html'),
          'ajax_memo_list.php': _read('todayhumor/comments_483503.json'),
        }),
      );

      final detail = unwrapRight(await repo.fetchDetail('483503'));

      // 17 memos total; skip 1 deleted + 2 system → 14 valid.
      // Top-level (parent_memo_no == 0) valid comments = 7.
      expect(detail.comments, hasLength(7));

      final first = detail.comments.first;
      expect(first.author, '우가가');
      expect(first.recommendCount, 8);
      expect(first.content, isNotEmpty);

      // No system/deleted comments leak through.
      expect(detail.comments.every((c) => c.author != 'SYSTEM'), isTrue);

      // 102572290 has 6 direct replies, one of which (lovingyou) has its own
      // nested reply → multi-level nesting works.
      expect(first.replies, hasLength(6));
      final lovingyou = first.replies.firstWhere(
        (c) => c.author == 'lovingyou',
      );
      expect(lovingyou.replies, hasLength(1));
    });

    test(
      'parses comment memo images into mediaBlocks (absolute url)',
      () async {
        final ajaxWithImage = jsonEncode({
          'is_more_memo': 'false',
          'memos': [
            {
              'no': '1',
              'parent_memo_no': 0,
              'is_system': false,
              'is_del': false,
              'name': '작성자',
              'date': '2026-07-27 19:39:52',
              'ok': '3',
              'memo': '사진입니다<img src="/board/img/photo.png">',
            },
          ],
        });

        final repo = TodayhumorImpl(
          htmlClient: _FixtureHtmlService({
            'view.php': _read('todayhumor/detail_483503.html'),
            'ajax_memo_list.php': ajaxWithImage,
          }),
        );

        final detail = unwrapRight(await repo.fetchDetail('483503'));

        expect(detail.comments, hasLength(1));
        final comment = detail.comments.first;
        expect(comment.mediaBlocks, hasLength(1));
        final block = comment.mediaBlocks.single as ImageBlock;
        expect(block.url, 'https://www.todayhumor.co.kr/board/img/photo.png');
      },
    );

    test('returns empty comments when ajax call fails', () async {
      final repo = TodayhumorImpl(
        htmlClient: _FixtureHtmlService({
          'view.php': _read('todayhumor/detail_483503.html'),
          // ajax_memo_list.php intentionally missing → get() throws.
        }),
      );

      final detail = unwrapRight(await repo.fetchDetail('483503'));

      expect(detail.comments, isEmpty);
      expect(detail.community, CommunityId.todayhumor);
    });
  });
}
