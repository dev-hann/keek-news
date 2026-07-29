import 'package:html/parser.dart' as html_parser;

import 'package:happy_news/data/models/post_dto.dart';

class MainPageParser {
  static List<PostDto> parseBestPosts(String htmlString) {
    if (htmlString.isEmpty) return [];

    final doc = html_parser.parse(htmlString);
    final items = doc.querySelectorAll('[id^="pds_best_li_"]');

    if (items.isEmpty) return [];

    return items.map((li) {
      final idAttr = li.id;
      final id = int.tryParse(idAttr.replaceFirst('pds_best_li_', '')) ?? 0;

      final span = li.querySelector('[id^="title_chk_pds-"]');
      final title = span?.text.trim() ?? '';

      final em = li.querySelector('em');
      final recommendCount = int.tryParse(em?.text.trim() ?? '0') ?? 0;

      final anchor = li.parent;
      final href = anchor?.attributes['href'] ?? '';
      final url = _extractPostUrl(href);

      return PostDto(
        id: id,
        title: title,
        recommendCount: recommendCount,
        url: url,
      );
    }).toList();
  }

  static String _extractPostUrl(String href) {
    if (href.isEmpty) return '';
    final uri = Uri.tryParse(href);
    if (uri == null) return href;
    final path = uri.queryParameters['url'] ?? '';
    final table = uri.queryParameters['table'] ?? '';
    final number = uri.queryParameters['number'] ?? '';
    if (path.isEmpty || table.isEmpty || number.isEmpty) return href;
    return '$path?table=$table&number=$number';
  }
}
