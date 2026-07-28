import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'package:humoruniv/data/models/feed_item_dto.dart';
import 'package:humoruniv/domain/entities/community.dart';

class TodayhumorListParser {
  static List<FeedItemDto> parse(String htmlString) {
    if (htmlString.isEmpty) return [];

    final doc = html_parser.parse(htmlString);
    final rows = doc.querySelectorAll('tr.view');

    return rows
        .map(_parseRow)
        .whereType<FeedItemDto>()
        .toList();
  }

  static FeedItemDto? _parseRow(dom.Element row) {
    final noTd = row.querySelector('td.no a');
    final subjectTd = row.querySelector('td.subject a');
    final nameTd = row.querySelector('td.name a');
    final dateTd = row.querySelector('td.date');
    final hitsTd = row.querySelector('td.hits');
    final oknokTd = row.querySelector('td.oknok');
    final commentSpan = row.querySelector(
      'td.subject span.list_memo_count_span',
    );

    if (noTd == null || subjectTd == null) return null;

    return FeedItemDto(
      community: CommunityId.todayhumor,
      id: _extractNo(noTd),
      title: subjectTd.text.trim(),
      url: subjectTd.attributes['href'] ?? '',
      author: nameTd?.text.trim() ?? '',
      publishedAt: _parseDate(dateTd?.text.trim() ?? ''),
      viewCount: int.tryParse(hitsTd?.text.trim() ?? '') ?? 0,
      recommendCount: int.tryParse(oknokTd?.text.trim() ?? '') ?? 0,
      commentCount: _parseCommentCount(commentSpan?.text ?? ''),
    );
  }

  static String _extractNo(dom.Element a) {
    final href = a.attributes['href'] ?? '';
    final match = RegExp(r'no=(\d+)').firstMatch(href);
    return match?.group(1) ?? a.text.trim();
  }

  static DateTime? _parseDate(String text) {
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

  static int _parseCommentCount(String text) {
    final match = RegExp(r'\[(\d+)\]').firstMatch(text);
    return match != null ? int.parse(match.group(1)!) : 0;
  }
}
