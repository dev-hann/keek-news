import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/content_scan_result.dart';
import 'package:keek_news/repository/community/humoruniv/humoruniv_impl.dart';
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

String _read(String path) => File('test/fixtures/$path').readAsStringSync();

void main() {
  group('HumorunivImpl.fetchDetail comment dates', () {
    test('regular comments do not fall back to epoch (1970)', () async {
      final repo = HumorunivImpl(
        htmlClient: _FixtureHtmlService({
          'read.html': _read('pds_1415455.html'),
        }),
      );

      final detail = await repo.fetchDetail('1415455');

      expect(detail.comments, isNotEmpty);
      for (final c in detail.comments) {
        expect(
          c.date.year,
          greaterThanOrEqualTo(2020),
          reason:
              'comment date must not be epoch (1970): ${c.author} '
              '${c.date}',
        );
      }
    });

    test('parses noisy regular comment date (b0ss -> 2026-06-27)', () async {
      final repo = HumorunivImpl(
        htmlClient: _FixtureHtmlService({
          'read.html': _read('pds_1415455.html'),
        }),
      );

      final detail = await repo.fetchDetail('1415455');

      final b0ss = detail.comments.firstWhere((c) => c.author == 'b0ss');
      expect(b0ss.date.year, 2026);
      expect(b0ss.date.month, 6);
      expect(b0ss.date.day, 27);
    });

    test('parses clean best comment date with time', () async {
      final repo = HumorunivImpl(
        htmlClient: _FixtureHtmlService({
          'read.html': _read('pds_1415455.html'),
        }),
      );

      final detail = await repo.fetchDetail('1415455');

      final best = detail.comments.firstWhere((c) => c.author == '클로저스');
      expect(best.isBest, isTrue);
      expect(best.date, DateTime(2026, 6, 27, 18, 57, 7));
    });
  });

  group('HumorunivImpl.fetchDetail NSFW placeholder leak', () {
    // Post 1419769 has a best-comment whose image was AI-flagged by
    // humoruniv's "너굴맨" moderation, producing a placeholder block
    // (class .comment_file > #racy_show_*) with strings like
    // "히든처리 되었습니다" / "너굴맨 설정" / "본문 너굴맨 한꺼번에 제거".
    // The parser must NOT pull those into the comment content.
    final forbidden = ['히든처리', '너굴맨', '이미지 보기', '너굴맨 설정', '본문 너굴맨', '한꺼번에 제거'];

    late HumorunivImpl repo;
    setUp(() {
      repo = HumorunivImpl(
        htmlClient: _FixtureHtmlService({
          'read.html': _read('pds_1419769.html'),
        }),
      );
    });

    test(
      'best-comment content does not contain NSFW placeholder text',
      () async {
        final detail = await repo.fetchDetail('1419769');

        final best = detail.comments.where((c) => c.isBest).toList();
        expect(
          best,
          isNotEmpty,
          reason: 'fixture must contain at least one best comment',
        );

        for (final c in detail.comments) {
          for (final keyword in forbidden) {
            expect(
              c.content,
              isNot(contains(keyword)),
              reason:
                  'comment by "${c.author}" leaked placeholder "$keyword": '
                  '${c.content}',
            );
          }
        }
      },
    );

    test('best-comment preserves real text alongside hidden media', () async {
      final detail = await repo.fetchDetail('1419769');

      final best = detail.comments.firstWhere((c) => c.isBest);
      expect(
        best.content,
        contains('뭐야'),
        reason: 'real best-comment text must survive: ${best.content}',
      );
    });
  });
}
