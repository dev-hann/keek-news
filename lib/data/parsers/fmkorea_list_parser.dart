import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'package:humoruniv/data/models/feed_item_dto.dart';
import 'package:humoruniv/domain/entities/community.dart';

class FmkoreaListParser {
  static List<FeedItemDto> parse(String htmlString) {
    if (htmlString.isEmpty) return [];

    final doc = html_parser.parse(htmlString);
    final rows = doc.querySelectorAll('li');

    return rows
        .map(_parseRow)
        .whereType<FeedItemDto>()
        .toList();
  }

  static FeedItemDto? _parseRow(dom.Element row) {
    final titleLink = row.querySelector('h3.title a');
    if (titleLink == null) return null;

    final href = titleLink.attributes['href'] ?? '';
    final id = _extractId(href);
    if (id.isEmpty) return null;

    final titleSpan = row.querySelector('span.ellipsis-target');
    final title = titleSpan?.text.trim() ?? titleLink.text.trim();

    final authorSpan = row.querySelector('span.author');
    final author = authorSpan?.text.replaceAll('/', '').trim() ?? '';

    final countSpan = row.querySelector('a.pc_voted_count span.count');
    final recommendCount = int.tryParse(countSpan?.text.trim() ?? '') ?? 0;

    final commentSpan = row.querySelector('span.comment_count');
    final commentText = commentSpan?.text ?? '';
    final commentMatch = RegExp(r'\[(\d+)\]').firstMatch(commentText);
    final commentCount =
        commentMatch != null ? int.parse(commentMatch.group(1)!) : 0;

    final regdateSpan = row.querySelector('span.regdate');
    if (regdateSpan == null) return null;
    final timeText = regdateSpan.text.trim();
    final publishedAt = _parseRelativeTime(timeText);
    if (publishedAt == null) return null;

    final thumbImg = row.querySelector('img.thumb');
    final thumbSrc =
        thumbImg?.attributes['data-original'] ?? thumbImg?.attributes['src'];
    final thumbnailUrl = thumbSrc != null && thumbSrc.startsWith('//')
        ? 'https:$thumbSrc'
        : thumbSrc;

    return FeedItemDto(
      community: CommunityId.fmkorea,
      id: id,
      title: title,
      url: href,
      author: author,
      publishedAt: publishedAt,
      recommendCount: recommendCount,
      commentCount: commentCount,
      thumbnailUrl: thumbnailUrl,
    );
  }

  static String _extractId(String href) {
    final match = RegExp(r'/(\d{8,})').firstMatch(href);
    return match?.group(1) ?? '';
  }

  static DateTime? _parseRelativeTime(String text) {
    final now = DateTime.now();

    var match = RegExp(r'(\d+)\s*분\s*전').firstMatch(text);
    if (match != null) {
      return now.subtract(Duration(minutes: int.parse(match.group(1)!)));
    }

    match = RegExp(r'(\d+)\s*시간\s*전').firstMatch(text);
    if (match != null) {
      return now.subtract(Duration(hours: int.parse(match.group(1)!)));
    }

    match = RegExp(r'(\d+)\s*일\s*전').firstMatch(text);
    if (match != null) {
      return now.subtract(Duration(days: int.parse(match.group(1)!)));
    }

    return null;
  }
}
