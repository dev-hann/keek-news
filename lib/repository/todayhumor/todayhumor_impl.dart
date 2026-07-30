import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/repository/community_repo.dart';
import 'package:keek_news/repository/todayhumor/todayhumor_repo.dart';
import 'package:keek_news/service/html_client.dart';
import 'package:keek_news/utils/media_classifier.dart';

class TodayhumorImpl implements TodayhumorRepo {
  TodayhumorImpl({required this.htmlClient});

  final HtmlClient htmlClient;

  @override
  CommunityId get communityId => CommunityId.todayhumor;

  @override
  Future<CommunityListResult> fetchLatest({String? pageToken}) async {
    try {
      final page = pageToken ?? '1';
      final html = await htmlClient.get(
        '/board/list.php?table=humorbest&page=$page',
      );
      final doc = html_parser.parse(html);
      final items = doc
          .querySelectorAll('tr.view')
          .map(_parseListRow)
          .whereType<FeedItem>()
          .toList();
      final nextPage = (int.tryParse(page) ?? 0) + 1;
      return CommunityListResult(
        items: items,
        pageToken: items.length >= 10 ? '$nextPage' : null,
      );
    } on ServerFailure {
      rethrow;
    } on NetworkFailure {
      rethrow;
    } catch (e) {
      debugPrint('TodayhumorImpl fetchLatest error: $e');
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<PostDetail> fetchDetail(String id) async {
    try {
      final html = await htmlClient.get(
        '/board/view.php?table=humorbest&no=$id',
      );
      final doc = html_parser.parse(html);
      final contentEl = doc.querySelector('.viewContent');
      final counts = _extractCounts(doc);

      return PostDetail(
        id: int.tryParse(id) ?? 0,
        title: _extractTitle(doc),
        author: _extractAuthor(doc),
        date: _extractDate(doc),
        contentHtml: contentEl?.innerHtml ?? '',
        contentBlocks: _buildBlocks(contentEl),
        imageUrls: _extractImages(contentEl),
        recommendCount: counts[0],
        notRecommendCount: 0,
        viewCount: counts[1],
        commentCount: counts[2],
        comments: const [],
        community: CommunityId.todayhumor,
      );
    } on ServerFailure {
      rethrow;
    } on NetworkFailure {
      rethrow;
    } catch (e) {
      debugPrint('TodayhumorImpl fetchDetail error: $e');
      throw ServerFailure(e.toString());
    }
  }

  FeedItem? _parseListRow(dom.Element row) {
    final noTd = row.querySelector('td.no a');
    final subjectTd = row.querySelector('td.subject a');
    if (noTd == null || subjectTd == null) return null;

    final nameTd = row.querySelector('td.name a');
    final dateTd = row.querySelector('td.date');
    final hitsTd = row.querySelector('td.hits');
    final oknokTd = row.querySelector('td.oknok');
    final commentSpan = row.querySelector(
      'td.subject span.list_memo_count_span',
    );

    final href = htmlClient.attrOf(subjectTd, 'href') ?? '';
    return FeedItem(
      community: CommunityId.todayhumor,
      id: _extractNo(noTd),
      title: subjectTd.text.trim(),
      url: href,
      author: htmlClient.textOf(nameTd),
      publishedAt: _parseDate(dateTd?.text.trim() ?? ''),
      viewCount: int.tryParse(hitsTd?.text.trim() ?? '') ?? 0,
      recommendCount: int.tryParse(oknokTd?.text.trim() ?? '') ?? 0,
      commentCount: _parseCommentCount(commentSpan?.text ?? ''),
    );
  }

  String _extractNo(dom.Element a) {
    final href = a.attributes['href'] ?? '';
    final match = RegExp(r'no=(\d+)').firstMatch(href);
    return match?.group(1) ?? a.text.trim();
  }

  DateTime? _parseDate(String text) {
    final match = RegExp(
      r'(\d{2})/(\d{2})/(\d{2})\s+(\d{2}):(\d{2})',
    ).firstMatch(text);
    if (match == null) return null;
    return DateTime(
      2000 + int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
    );
  }

  int _parseCommentCount(String text) {
    final match = RegExp(r'\[(\d+)\]').firstMatch(text);
    return match != null ? int.parse(match.group(1)!) : 0;
  }

  String _extractTitle(dom.Document doc) {
    final el = doc.querySelector('.viewSubjectDiv');
    final text = el?.text.trim() ?? '';
    final match = RegExp(
      '<!--EAP_SUBJECT-->(.*)<!--/EAP_SUBJECT-->',
    ).firstMatch(el?.innerHtml ?? '');
    return match?.group(1)?.trim() ?? text;
  }

  String _extractAuthor(dom.Document doc) {
    final el = doc.querySelector('#viewPageWriterNameSpan');
    final nameAttr = el?.attributes['name'];
    if (nameAttr != null && nameAttr.isNotEmpty) return nameAttr;
    final b = el?.querySelector('b');
    return b?.text.trim() ?? el?.text.trim() ?? '';
  }

  DateTime _extractDate(dom.Document doc) {
    final container = doc.querySelector('.writerInfoContents');
    final text = container?.text ?? '';
    final match = RegExp(
      r'(\d{4})/(\d{2})/(\d{2})\s+(\d{2}):(\d{2}):(\d{2})',
    ).firstMatch(text);
    if (match == null) return DateTime.now();
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
  }

  List<String> _extractImages(dom.Element? content) {
    if (content == null) return const [];
    return content
        .querySelectorAll('img')
        .where((img) {
          final src = img.attributes['src'] ?? '';
          return src.contains('todayhumor') || src.startsWith('http');
        })
        .map((img) => img.attributes['src'] ?? '')
        .where((src) => src.isNotEmpty)
        .where(MediaClassifier.isLoadableImage)
        .toList();
  }

  List<ContentBlock> _buildBlocks(dom.Element? content) {
    if (content == null) return const [];
    final blocks = <ContentBlock>[];

    for (final child in content.children) {
      final videos = child.querySelectorAll('video');
      if (videos.isNotEmpty) {
        for (final video in videos) {
          for (final source in video.querySelectorAll('source')) {
            final src = source.attributes['src'] ?? '';
            if (src.isNotEmpty && src.contains('.mp4')) {
              final full = src.startsWith('//') ? 'https:$src' : src;
              if (!blocks.any((b) => b is VideoBlock && b.url == full)) {
                blocks.add(VideoBlock(url: full));
              }
            }
          }
        }
        continue;
      }

      final imgs = child.querySelectorAll('img');
      if (imgs.isNotEmpty) {
        for (final img in imgs) {
          final src = img.attributes['src'] ?? '';
          if (src.isNotEmpty) {
            blocks.add(ImageBlock(url: src));
          }
        }
      } else {
        final text = child.text.trim();
        if (text.isNotEmpty &&
            !text.contains('browser does not support') &&
            !text.contains('브라우저')) {
          blocks.add(TextBlock(text));
        }
      }
    }

    if (blocks.isEmpty && content.text.trim().isNotEmpty) {
      blocks.add(TextBlock(content.text.trim()));
    }

    return blocks;
  }

  List<int> _extractCounts(dom.Document doc) {
    final container = doc.querySelector('.writerInfoContents');
    final text = container?.text ?? '';
    final okMatch = RegExp(r'추천\s*:\s*(\d+)').firstMatch(text);
    final hitsMatch = RegExp(r'조회수\s*:\s*(\d+)').firstMatch(text);
    final commentMatch = RegExp(r'댓글\s*:\s*(\d+)').firstMatch(text);
    return [
      int.tryParse(okMatch?.group(1) ?? '') ?? 0,
      int.tryParse(hitsMatch?.group(1) ?? '') ?? 0,
      int.tryParse(commentMatch?.group(1) ?? '') ?? 0,
    ];
  }
}
