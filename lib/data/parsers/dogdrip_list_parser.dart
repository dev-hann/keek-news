import 'package:happy_news/data/models/feed_item_dto.dart';
import 'package:happy_news/domain/entities/community.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

class DogdripListParser {
  static List<FeedItemDto> parse(String htmlString) {
    if (htmlString.isEmpty) return [];

    final doc = html_parser.parse(htmlString);
    final rows = doc.querySelectorAll('li.webzine');

    return rows.map(_parseRow).whereType<FeedItemDto>().toList();
  }

  static FeedItemDto? _parseRow(dom.Element row) {
    final titleLink = row.querySelector('a.title-link');
    if (titleLink == null) return null;

    final id = titleLink.attributes['data-document-srl'] ?? '';
    if (id.isEmpty) return null;

    final url = titleLink.attributes['href'] ?? '';
    final title = titleLink.text.trim();

    final authorLink = row.querySelector('a[class*="member_"]');
    final author = authorLink?.text.trim() ?? '';

    final metaDiv = row.querySelector('div.ed.flex.list-meta');
    final recommendText = metaDiv?.querySelector('span.text-primary')?.text;
    final recommendCount = int.tryParse((recommendText ?? '').trim()) ?? 0;

    final timeText = metaDiv?.text ?? '';
    final publishedAt = _parseRelativeTime(timeText);

    final thumbnail = row.querySelector('img.webzine-thumbnail');
    final thumbnailUrl = thumbnail?.attributes['src'];

    return FeedItemDto(
      community: CommunityId.dogdrip,
      id: id,
      title: title,
      url: url,
      author: author,
      publishedAt: publishedAt,
      recommendCount: recommendCount,
      thumbnailUrl: thumbnailUrl != null && thumbnailUrl.isNotEmpty
          ? (thumbnailUrl.startsWith('/')
                ? 'https://www.dogdrip.net$thumbnailUrl'
                : thumbnailUrl)
          : null,
    );
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
