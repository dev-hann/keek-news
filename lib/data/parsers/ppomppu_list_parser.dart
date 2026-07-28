import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'package:humoruniv/data/models/feed_item_dto.dart';
import 'package:humoruniv/domain/entities/community.dart';

class PpomppuListParser {
  static List<FeedItemDto> parse(String htmlString) {
    if (htmlString.isEmpty) return [];

    final doc = html_parser.parse(htmlString);
    final rows = doc.querySelectorAll('tr.baseList');

    return rows.map(_parseRow).whereType<FeedItemDto>().toList();
  }

  static FeedItemDto? _parseRow(dom.Element row) {
    final titleLink = row.querySelector('a.baseList-title');
    final numbTd = row.querySelector('td.baseList-numb');
    final nameSpan = row.querySelector('span.baseList-name');
    final timeTd = row.querySelector('td.baseList-time');
    final dateTd = row.querySelector('td[title]');
    final recTd = row.querySelector('td.baseList-rec');
    final viewsTd = row.querySelector('td.baseList-views');
    final imgIcon = row.querySelector('img.baseList-img');

    if (titleLink == null || numbTd == null) return null;

    final href = titleLink.attributes['href'] ?? '';
    final no = _extractNo(href);
    if (no.isEmpty) return null;

    final titleSpan = titleLink.querySelector('span');
    final title = (titleSpan?.text ?? titleLink.text).trim();

    return FeedItemDto(
      community: CommunityId.ppomppu,
      id: no,
      title: title,
      url: href,
      author: nameSpan?.text.trim() ?? '',
      publishedAt: _parseDate(dateTd?.attributes['title'], timeTd?.text),
      recommendCount: int.tryParse(recTd?.text.trim() ?? '') ?? 0,
      viewCount: int.tryParse(viewsTd?.text.trim() ?? '') ?? 0,
      thumbnailUrl: imgIcon?.attributes['src'],
    );
  }

  static String _extractNo(String href) {
    final match = RegExp(r'no=(\d+)').firstMatch(href);
    return match?.group(1) ?? '';
  }

  static DateTime? _parseDate(String? fullDate, String? time) {
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
}
