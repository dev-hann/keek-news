import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:keek_news/model/comment.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/repository/community/html_community_repo.dart';
import 'package:keek_news/service/html_service.dart';

class TodayhumorImpl extends HtmlCommunityRepo {
  TodayhumorImpl({required super.htmlClient});

  @override
  CommunityId get communityId => CommunityId.todayhumor;

  @override
  String listPath(String page) => '/board/list.php?table=humorbest&page=$page';

  @override
  String listRowSelector() => 'tr.view';

  @override
  int get listPageSize => 10;

  @override
  ContentBlockConfig get contentBlockConfig => const ContentBlockConfig(
    community: CommunityId.todayhumor,
    dedupStrategy: DedupStrategy.exactUrl,
    resolveImageUrls: false,
  );

  @override
  Future<LoadedPostDetail> fetchDetail(String id) async {
    final html = await htmlClient.get('/board/view.php?table=humorbest&no=$id');
    final doc = html_parser.parse(html);
    final contentEl = doc.querySelector('.viewContent');
    final counts = _extractCounts(doc);

    return LoadedPostDetail(
      id: int.tryParse(id) ?? 0,
      title: _extractTitle(doc),
      author: _extractAuthor(doc),
      date: _extractDate(doc),
      contentBlocks: buildBlocks(contentEl),
      imageUrls: htmlClient.collectImageUrls(
        contentEl,
        community: communityId,
        includeFilter: (src) =>
            src.contains('todayhumor') || src.startsWith('http'),
      ),
      recommendCount: counts[0],
      notRecommendCount: 0,
      viewCount: counts[1],
      commentCount: counts[2],
      comments: await _fetchComments(html),
      community: CommunityId.todayhumor,
    );
  }

  @override
  FeedItem? parseListRow(dom.Element row) {
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
      viewCount: htmlClient.extractNumber(hitsTd?.text),
      recommendCount: htmlClient.extractNumber(oknokTd?.text),
      commentCount: htmlClient.extractBracketedInt(commentSpan?.text ?? ''),
    );
  }

  String _extractNo(dom.Element a) {
    final href = a.attributes['href'] ?? '';
    return htmlClient.extractQueryParam(href, 'no') ?? a.text.trim();
  }

  DateTime? _parseDate(String text) {
    return parseDatePattern(
      text,
      RegExp(r'(\d{2})/(\d{2})/(\d{2})\s+(\d{2}):(\d{2})'),
      year2: true,
    );
  }

  String _extractTitle(dom.Document doc) {
    final el = htmlClient.queryFirst(doc.body, const [
      '.viewSubjectDiv',
      '.view_subject',
      '.subject',
      'h1.view_subject',
      '[itemprop="headline"]',
    ]);
    final text = el?.text.trim() ?? '';
    final match = RegExp(
      '<!--EAP_SUBJECT-->(.*)<!--/EAP_SUBJECT-->',
    ).firstMatch(el?.innerHtml ?? '');
    return match?.group(1)?.trim() ?? text;
  }

  String _extractAuthor(dom.Document doc) {
    final el = htmlClient.queryFirst(doc.body, const [
      '#viewPageWriterNameSpan',
      '.writer_name',
      '.author',
      '.nick_name',
      '[itemprop="author"]',
    ]);
    final nameAttr = el?.attributes['name'];
    if (nameAttr != null && nameAttr.isNotEmpty) return nameAttr;
    final b = el?.querySelector('b');
    return b?.text.trim() ?? el?.text.trim() ?? '';
  }

  DateTime _extractDate(dom.Document doc) {
    final container = htmlClient.queryFirst(doc.body, const [
      '.writerInfoContents',
      '.writer_info',
      '.view_meta',
      '.post_meta',
    ]);
    final text = container?.text ?? '';
    return parseDatePattern(
          text,
          RegExp(r'(\d{4})/(\d{2})/(\d{2})\s+(\d{2}):(\d{2}):(\d{2})'),
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
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

  Future<List<Comment>> _fetchComments(String viewHtml) async {
    final parentTable = _extractJsVar(viewHtml, 'parent_table');
    final parentId = _extractJsVar(viewHtml, 'parent_id');
    if (parentTable == null || parentId == null) return const [];
    try {
      final raw = await htmlClient.get(
        '/board/ajax_memo_list.php?parent_table=$parentTable'
        '&parent_id=$parentId&last_memo_no=0',
      );
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const [];
      final memos = decoded['memos'];
      if (memos is! List) return const [];
      return _buildCommentTree(memos);
    } catch (e) {
      debugPrint('TodayhumorImpl comments error: $e');
      return const [];
    }
  }

  String? _extractJsVar(String html, String name) {
    final match = RegExp('var $name = "([^"]+)"').firstMatch(html);
    return match?.group(1);
  }

  List<Comment> _buildCommentTree(List<dynamic> memos) {
    final byParent = <int, List<Map<String, dynamic>>>{};
    final topLevel = <Map<String, dynamic>>[];
    for (final raw in memos) {
      if (raw is! Map<String, dynamic>) continue;
      if (raw['is_del'] == true || raw['is_system'] == true) continue;
      final parent = htmlClient.toInt(raw['parent_memo_no']);
      if (parent == 0) {
        topLevel.add(raw);
      } else {
        byParent.putIfAbsent(parent, () => []).add(raw);
      }
    }
    return topLevel.map((m) => _toComment(m, byParent)).toList();
  }

  Comment _toComment(
    Map<String, dynamic> m,
    Map<int, List<Map<String, dynamic>>> byParent,
  ) {
    final no = htmlClient.toInt(m['no']);
    final parsed = _parseMemo((m['memo'] as String?) ?? '');
    final replies = (byParent[no] ?? [])
        .map((c) => _toComment(c, byParent))
        .toList();
    return Comment(
      id: no,
      author: (m['name'] as String?) ?? '',
      content: parsed.text,
      date:
          DateTime.tryParse((m['date'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      recommendCount: htmlClient.toInt(m['ok']),
      isBest: false,
      replies: replies,
      mediaBlocks: parsed.media,
    );
  }

  ({String text, List<ContentBlock> media}) _parseMemo(String html) {
    return htmlClient.parseFragmentMemo(
      html,
      community: communityId,
      preserveBreaks: true,
    );
  }
}
