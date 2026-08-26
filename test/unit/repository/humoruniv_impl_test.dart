import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/content_scan_result.dart';
import 'package:keek_news/repository/community/humoruniv/humoruniv_impl.dart';
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

/// Same fixture plumbing as [_FixtureHtmlService] but inherits the real
/// ContentScanner-backed scan* implementations from [HtmlService].
class _ScanningHtmlService extends HtmlService
    with HtmlServiceMultiCandidateMixin {
  _ScanningHtmlService(this._fixtures);
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

    test('parses regular comment date (단수돌침대 -> 2026-06-27)', () async {
      final repo = HumorunivImpl(
        htmlClient: _FixtureHtmlService({
          'read.html': _read('pds_1415455.html'),
        }),
      );

      final detail = await repo.fetchDetail('1415455');

      final comment = detail.comments.firstWhere((c) => c.author == '단수돌침대');
      expect(comment.date, DateTime(2026, 6, 27, 18, 56, 44));
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

  group('HumorunivImpl.fetchDetail comment_more redesign (2026-08)', () {
    // 2026-08 humoruniv dropped `.comment_text` and now wraps comment
    // bodies in `.comment_more` with a hidden-by-CSS sibling
    // `.comment_more_btn` rendered as `...전체보기`. The expander markup
    // ships in the HTML for EVERY comment, so the parser must read body
    // text from `.comment_more` and never leak the button text.
    test('comment content never leaks 전체보기 expander text', () async {
      final repo = HumorunivImpl(
        htmlClient: _FixtureHtmlService({
          'read.html': _read('pds_1419769.html'),
        }),
      );

      final detail = await repo.fetchDetail('1419769');

      expect(detail.comments, isNotEmpty);
      for (final c in detail.comments) {
        expect(
          c.content,
          isNot(contains('전체보기')),
          reason: 'comment by "${c.author}" leaked the expander: ${c.content}',
        );
      }
    });

    test('long comment keeps full untruncated text', () async {
      final repo = HumorunivImpl(
        htmlClient: _FixtureHtmlService({
          'read.html': _read('pds_1419653.html'),
        }),
      );

      final detail = await repo.fetchDetail('1419653');

      final long = detail.comments.firstWhere((c) => c.id == 515532327);
      expect(long.author, 'doksoori4');
      expect(long.content, startsWith('내가 썼던 글'));
      expect(
        long.content.length,
        greaterThan(500),
        reason: 'comment_more text must be complete, got: ${long.content}',
      );
    });

    test('short comment strips trailing expander dots', () async {
      final repo = HumorunivImpl(
        htmlClient: _FixtureHtmlService({
          'read.html': _read('pds_1419653.html'),
        }),
      );

      final detail = await repo.fetchDetail('1419653');

      final short = detail.comments.firstWhere((c) => c.id == 515531624);
      expect(short.author, '포브스선정이딸');
      expect(short.content, '어시..발?');
    });

    test('comment image markup stays out of content text', () async {
      final repo = HumorunivImpl(
        htmlClient: _FixtureHtmlService({
          'read.html': _read('pds_1419653.html'),
        }),
      );

      final detail = await repo.fetchDetail('1419653');

      final withImage = detail.comments.firstWhere((c) => c.id == 515500234);
      expect(withImage.content, contains('노브레인형님'));
      expect(withImage.content, isNot(contains('comment_crop')));
      expect(withImage.content, isNot(contains('gif')));
    });
  });

  group('HumorunivImpl.fetchDetail reply-count badge + replies', () {
    // Since the 2026-08 redesign the reply-count badge `span.comment_num`
    // ("[N]") is nested INSIDE `.comment_more`, and reply `li`s
    // (`sub_comm_bt`) sit after a malformed double `</li>` close.
    test('reply-count badge [N] is stripped from parent content', () async {
      final repo = HumorunivImpl(
        htmlClient: _FixtureHtmlService({
          'read.html': _read('pds_1419653.html'),
        }),
      );

      final detail = await repo.fetchDetail('1419653');

      for (final c in detail.comments) {
        expect(
          RegExp(r'\[\d+\]').hasMatch(c.content),
          isFalse,
          reason: 'comment by "${c.author}" leaked reply badge: ${c.content}',
        );
      }

      final badge = detail.comments.firstWhere((c) => c.id == 515531716);
      expect(badge.author, '짤방댓글러');
      expect(badge.content, startsWith('락덕후들이'));
    });

    test('nested replies attach to parent, not dropped', () async {
      final repo = HumorunivImpl(
        htmlClient: _FixtureHtmlService({
          'read.html': _read('pds_1419653.html'),
        }),
      );

      final detail = await repo.fetchDetail('1419653');

      final parent = detail.comments.firstWhere((c) => c.id == 515500234);
      expect(
        parent.replies,
        isNotEmpty,
        reason:
            'parent 515500234 must keep its sub_comm_bt replies; '
            'got ${parent.replies.length}',
      );
      expect(parent.replies.map((r) => r.author), contains('개똥이아부지'));
      for (final reply in parent.replies) {
        expect(reply.content, isNot(contains('전체보기')));
        expect(reply.content, isNot(contains('[')));
      }
    });
  });

  group('HumorunivImpl.fetchDetail video thumbnail synthesis', () {
    // Thumbnail-less VideoBlocks render as a permanent white circlePlay
    // placeholder in the feed carousel. humoruniv serves session-free
    // posters via timg.humoruniv.com/thumb.php?url=<media>, so the parser
    // must synthesize one whenever a video ships without its own poster.
    test('body VideoBlocks get a synthesized timg poster', () async {
      final repo = HumorunivImpl(
        htmlClient: _ScanningHtmlService({
          'read.html': _read('pds_1419653.html'),
        }),
      );

      final detail = await repo.fetchDetail('1419653');

      final videos = detail.contentBlocks.whereType<VideoBlock>().toList();
      expect(videos, isNotEmpty, reason: 'fixture must contain a video');
      for (final v in videos) {
        expect(
          v.thumbnailUrl,
          startsWith('https://timg.humoruniv.com/thumb.php?url='),
          reason: 'video ${v.url} has no synthesized poster',
        );
      }
      expect(
        videos.any(
          (v) =>
              v.thumbnailUrl ==
              'https://timg.humoruniv.com/thumb.php?url=${v.url}',
        ),
        isTrue,
        reason: 'at least one poster must be synthesized (not pre-existing)',
      );
    });

    test('comment VideoBlocks get a synthesized timg poster', () async {
      final repo = HumorunivImpl(
        htmlClient: _ScanningHtmlService({
          'read.html': _read('pds_1415455.html'),
        }),
      );

      final detail = await repo.fetchDetail('1415455');

      final commentVideos = <VideoBlock>[
        for (final c in detail.comments)
          ...c.mediaBlocks.whereType<VideoBlock>(),
      ];
      expect(commentVideos, isNotEmpty, reason: 'fixture has comment mp4s');
      for (final v in commentVideos) {
        expect(
          v.thumbnailUrl,
          startsWith('https://timg.humoruniv.com/thumb.php?url='),
          reason: 'comment video ${v.url} has no synthesized poster',
        );
      }
    });
  });

  group('HumorunivImpl.fetchDetail url_enc session thumbs (1422694)', () {
    // Body mp4 thumbs ship as `thumb.php?url_enc=<session-token>` images.
    // Left in, the token image becomes a dead first carousel page (white
    // retry card) and the video keeps an expiring poster. The scanner must
    // drop both so the carousel is [real photo, video(synthesized poster)].
    test('url_enc images never reach imageUrls or blocks', () async {
      final repo = HumorunivImpl(
        htmlClient: _ScanningHtmlService({
          'read.html': _read('pds_1422694.html'),
        }),
      );

      final detail = await repo.fetchDetail('1422694');

      for (final url in detail.imageUrls) {
        expect(
          url,
          isNot(contains('url_enc=')),
          reason: 'session thumb leaked into imageUrls: $url',
        );
      }
      for (final block in detail.contentBlocks) {
        if (block is ImageBlock) {
          expect(block.url, isNot(contains('url_enc=')));
        }
      }
    });

    test(
      'carousel media is exactly one webp photo + one video with poster',
      () async {
        final repo = HumorunivImpl(
          htmlClient: _ScanningHtmlService({
            'read.html': _read('pds_1422694.html'),
          }),
        );

        final detail = await repo.fetchDetail('1422694');

        expect(detail.imageUrls, hasLength(1));
        expect(
          detail.imageUrls.single,
          contains(
            'e_s02d384002_4451848a5446823511254c0de5c803fe529e8f9d.webp',
          ),
        );

        final videos = detail.contentBlocks.whereType<VideoBlock>().toList();
        expect(videos, hasLength(1));
        expect(
          videos.single.url,
          contains('e_s02d384001_8de4aca03a6231489ab7fb65899fc6a4e6dcc796.mp4'),
        );
        expect(
          videos.single.thumbnailUrl,
          'https://timg.humoruniv.com/thumb.php?url=${videos.single.url}',
          reason: 'poster must be synthesized, not a session token',
        );
      },
    );
  });
}
