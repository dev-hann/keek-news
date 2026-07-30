import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:keek_news/model/comment.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/repository/community_repo.dart';
import 'package:keek_news/repository/ppomppu/ppomppu_repo.dart';
import 'package:keek_news/service/html_client.dart';
import 'package:keek_news/utils/media_classifier.dart';

class PpomppuImpl implements PpomppuRepo {
  PpomppuImpl({required this.htmlClient});

  final HtmlClient htmlClient;

  @override
  CommunityId get communityId => CommunityId.ppomppu;

  @override
  Future<CommunityListResult> fetchLatest({String? pageToken}) async {
    try {
      final page = pageToken ?? '1';
      final html = await htmlClient.get(
        '/zboard/zboard.php?id=humor&page=$page',
      );
      final doc = html_parser.parse(html);
      final items = doc
          .querySelectorAll('tr.baseList')
          .map(_parseListRow)
          .whereType<FeedItem>()
          .toList();
      final nextPage = (int.tryParse(page) ?? 0) + 1;
      return CommunityListResult(
        items: items,
        pageToken: items.length >= 5 ? '$nextPage' : null,
      );
    } on ServerFailure {
      rethrow;
    } on NetworkFailure {
      rethrow;
    } catch (e) {
      debugPrint('PpomppuImpl fetchLatest error: $e');
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<PostDetail> fetchDetail(String id) async {
    try {
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
        imageUrls: _extractImages(contentEl),
        recommendCount: 0,
        notRecommendCount: 0,
        viewCount: _extractViewCount(doc),
        commentCount: _extractCommentCount(commentData),
        comments: _extractComments(commentData, date),
        community: CommunityId.ppomppu,
      );
    } on ServerFailure {
      rethrow;
    } on NetworkFailure {
      rethrow;
    } catch (e) {
      debugPrint('PpomppuImpl fetchDetail error: $e');
      throw ServerFailure(e.toString());
    }
  }

  FeedItem? _parseListRow(dom.Element row) {
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
      recommendCount: int.tryParse(recTd?.text.trim() ?? '') ?? 0,
      viewCount: int.tryParse(viewsTd?.text.trim() ?? '') ?? 0,
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
    final match = RegExp(r'no=(\d+)').firstMatch(href);
    return match?.group(1) ?? '';
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

  List<String> _extractImages(dom.Element? content) {
    if (content == null) return const [];
    return content
        .querySelectorAll('img')
        .map((img) => img.attributes['src'] ?? '')
        .where((src) => src.isNotEmpty)
        .map((src) => src.startsWith('//') ? 'https:$src' : src)
        .where(MediaClassifier.isLoadableImage)
        .toList();
  }

  List<ContentBlock> _buildBlocks(dom.Element? content) {
    if (content == null) return const [];
    final blocks = <ContentBlock>[];
    for (final p in content.querySelectorAll('p')) {
      final videos = p.querySelectorAll('video');
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

      final imgs = p.querySelectorAll('img');
      if (imgs.isNotEmpty) {
        for (final img in imgs) {
          final src = img.attributes['src'] ?? '';
          if (src.isNotEmpty) {
            final full = src.startsWith('//') ? 'https:$src' : src;
            blocks.add(ImageBlock(url: full));
          }
        }
      } else {
        final text = p.text.trim();
        if (text.isNotEmpty &&
            !text.contains('browser does not support') &&
            !text.contains('브라우저') &&
            text != '\u00a0') {
          blocks.add(TextBlock(text));
        }
      }
    }
    return blocks;
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
    return (data['total_comment'] as num?)?.toInt() ?? 0;
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
      final id = (item['no'] as num?)?.toInt() ?? 0;
      final author = _stripTags(item['name'] as String? ?? '');
      final content = _stripTags(item['memo'] as String? ?? '');
      final voteBtn = item['vote_btn'];
      final recommend = voteBtn is Map<String, dynamic>
          ? (voteBtn['vote_count'] as num?)?.toInt() ?? 0
          : 0;
      final time = (item['meta'] is Map<String, dynamic>)
          ? (item['meta']!['time_display'] as String?)
          : null;

      result.add(
        Comment(
          id: id,
          author: author,
          content: content,
          date: _mergeTime(postDate, time),
          recommendCount: recommend,
          isBest: false,
          replies: const [],
        ),
      );
    }
    return result;
  }

  String _stripTags(String html) {
    final text = html_parser.parseFragment(html).text ?? '';
    return text.replaceAll('\u00a0', ' ').trim();
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
