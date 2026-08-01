import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:keek_news/model/comment.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/repository/community/html_community_repo.dart';
import 'package:keek_news/service/html_service.dart';

class PpomppuImpl extends HtmlCommunityRepo {
  PpomppuImpl({required super.htmlClient});

  @override
  CommunityId get communityId => CommunityId.ppomppu;

  @override
  String listPath(String page) => '/zboard/zboard.php?id=humor&page=$page';

  @override
  String listRowSelector() => 'tr.baseList';

  @override
  int get listPageSize => 5;

  @override
  Future<PostDetail> fetchDetail(String id) async {
    final html = await htmlClient.get('/zboard/view.php?id=humor&no=$id');
    final doc = html_parser.parse(html);
    final contentEl = doc.querySelector('.board-contents');
    final date = _extractDate(doc);
    final commentData = _extractCommentData(doc);

    return PostDetail(
      id: int.tryParse(id) ?? 0,
      title: _extractTitle(doc),
      author: _extractAuthor(doc),
      date: date,
      contentHtml: contentEl?.innerHtml ?? '',
      contentBlocks: _buildBlocks(contentEl),
      imageUrls: htmlClient.collectImageUrls(
        contentEl,
        community: communityId,
        includeFilter: _isNotUiAsset,
      ),
      recommendCount: 0,
      notRecommendCount: 0,
      viewCount: _extractViewCount(doc),
      commentCount: _extractCommentCount(commentData),
      comments: _extractComments(commentData, date),
      community: CommunityId.ppomppu,
    );
  }

  @override
  FeedItem? parseListRow(dom.Element row) {
    final titleLink = row.querySelector('a.baseList-title');
    final numbTd = row.querySelector('td.baseList-numb');
    if (titleLink == null || numbTd == null) return null;

    final href = htmlClient.attrOf(titleLink, 'href') ?? '';
    final no = _extractNo(href);
    if (no.isEmpty) return null;

    final titleSpan = titleLink.querySelector('span');
    final title = (titleSpan?.text ?? titleLink.text).trim();
    final nameSpan = row.querySelector('span.baseList-name');
    final dateTd = row.querySelector('td[title]');
    final timeTd = row.querySelector('td.baseList-time');
    final recTd = row.querySelector('td.baseList-rec');
    final viewsTd = row.querySelector('td.baseList-views');
    final imgIcon = row.querySelector('img.baseList-img');
    final commentSpan = row.querySelector('span.baseList-c');

    return FeedItem(
      community: CommunityId.ppomppu,
      id: no,
      title: title,
      url: href,
      author: htmlClient.textOf(nameSpan),
      publishedAt: _parseDate(dateTd?.attributes['title'], timeTd?.text),
      recommendCount: htmlClient.extractNumber(recTd?.text),
      viewCount: htmlClient.extractNumber(viewsTd?.text),
      commentCount: _parseCommentCount(commentSpan?.text),
      thumbnailUrl: htmlClient.attrOf(imgIcon, 'src'),
    );
  }

  int _parseCommentCount(String? text) {
    if (text == null) return 0;
    final match = RegExp(r'(\d+)').firstMatch(text.trim());
    return match != null ? int.parse(match.group(1)!) : 0;
  }

  String _extractNo(String href) {
    return htmlClient.extractQueryParam(href, 'no') ?? '';
  }

  DateTime? _parseDate(String? fullDate, String? time) {
    if (fullDate != null && fullDate.isNotEmpty) {
      final match = RegExp(
        r'(\d{2})\.(\d{2})\.(\d{2})\s+(\d{2}):(\d{2}):(\d{2})',
      ).firstMatch(fullDate);
      if (match != null) {
        return DateTime(
          2000 + int.parse(match.group(1)!),
          int.parse(match.group(2)!),
          int.parse(match.group(3)!),
          int.parse(match.group(4)!),
          int.parse(match.group(5)!),
          int.parse(match.group(6)!),
        );
      }
    }
    return null;
  }

  String _extractTitle(dom.Document doc) {
    return htmlClient.textOf(doc.querySelector('#topTitle h1'));
  }

  String _extractAuthor(dom.Document doc) {
    return htmlClient.textOf(doc.querySelector('.topTitle-name a'));
  }

  DateTime _extractDate(dom.Document doc) {
    for (final li in doc.querySelectorAll('#topTitle li')) {
      final match = RegExp(
        r'(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})',
      ).firstMatch(li.text);
      if (match != null) {
        return DateTime(
          int.parse(match.group(1)!),
          int.parse(match.group(2)!),
          int.parse(match.group(3)!),
          int.parse(match.group(4)!),
          int.parse(match.group(5)!),
        );
      }
    }
    return DateTime.now();
  }

  bool _isNotUiAsset(String src) {
    final lower = src.toLowerCase();
    return !lower.contains('/images/') && !lower.contains('/skin/');
  }

  List<ContentBlock> _buildBlocks(dom.Element? content) {
    if (content == null) return const [];
    return htmlClient.buildContentBlocks(
      content.querySelectorAll('p'),
      const ContentBlockConfig(community: CommunityId.ppomppu, skipNbsp: true),
    );
  }

  int _extractViewCount(dom.Document doc) {
    for (final li in doc.querySelectorAll('#topTitle li')) {
      final match = RegExp(r'조회수\s*(\d+)').firstMatch(li.text);
      if (match != null) return int.parse(match.group(1)!);
    }
    return 0;
  }

  Map<String, dynamic>? _extractCommentData(dom.Document doc) {
    final match = RegExp(
      r'initialCommentData\s*=\s*(\{.*\})\s*;',
      dotAll: true,
    ).firstMatch(doc.outerHtml);
    if (match == null) return null;
    try {
      return jsonDecode(match.group(1)!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  int _extractCommentCount(Map<String, dynamic>? data) {
    if (data == null) return 0;
    return htmlClient.toInt(data['total_comment']);
  }

  List<Comment> _extractComments(
    Map<String, dynamic>? data,
    DateTime postDate,
  ) {
    if (data == null) return const [];
    final raw = data['comments'];
    if (raw is! List) return const [];

    final result = <Comment>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) continue;
      final id = htmlClient.toInt(item['no']);
      final author = _stripTags(item['name'] as String? ?? '');
      final parsed = _parseMemo(item['memo'] as String? ?? '');
      final voteBtn = item['vote_btn'];
      final recommend = voteBtn is Map<String, dynamic>
          ? htmlClient.toInt(voteBtn['vote_count'])
          : 0;
      final meta = item['meta'];
      final time = meta is Map<String, dynamic>
          ? (meta['time_display'] as String?)
          : null;

      result.add(
        Comment(
          id: id,
          author: author,
          content: parsed.text,
          date: _mergeTime(postDate, time),
          recommendCount: recommend,
          isBest: false,
          replies: const [],
          mediaBlocks: parsed.media,
        ),
      );
    }
    return result;
  }

  String _stripTags(String html) {
    return htmlClient.parseFragmentMemo(html, community: communityId).text;
  }

  ({String text, List<ContentBlock> media}) _parseMemo(String html) {
    return htmlClient.parseFragmentMemo(html, community: communityId);
  }

  DateTime _mergeTime(DateTime base, String? time) {
    if (time == null) return base;
    final match = RegExp(r'(\d{2}):(\d{2}):(\d{2})').firstMatch(time);
    if (match == null) return base;
    return DateTime(
      base.year,
      base.month,
      base.day,
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }
}
