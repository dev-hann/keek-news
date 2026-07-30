import 'package:happy_news/core/utils/media_classifier.dart';
import 'package:happy_news/data/models/board_post_dto.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

class BoardListParseResult {
  const BoardListParseResult({
    required this.posts,
    required this.currentPage,
    required this.totalPage,
  });
  final List<BoardPostDto> posts;
  final int currentPage;
  final int totalPage;
}

class BoardListParser {
  static BoardListParseResult parse(String htmlString) {
    if (htmlString.isEmpty) {
      return const BoardListParseResult(
        posts: [],
        currentPage: 0,
        totalPage: 0,
      );
    }

    final doc = html_parser.parse(htmlString);

    return BoardListParseResult(
      posts: _extractPosts(doc),
      currentPage: _extractCurrentPage(doc),
      totalPage: _extractTotalPage(doc),
    );
  }

  static List<BoardPostDto> _extractPosts(dom.Document doc) {
    final items = doc.querySelectorAll('div.post_item a.post_link');
    if (items.isEmpty) return [];

    return items.map((anchor) {
      final number = anchor.attributes['data-number'] ?? '';
      final id = int.tryParse(number) ?? 0;
      final href = anchor.attributes['href'] ?? '';
      final url = _buildPostUrl(href);

      final title = anchor.querySelector('span.link_hover')?.text.trim() ?? '';
      final thumbnailUrl = _extractThumbnail(anchor);
      final author =
          anchor.querySelector('span.hu_nick_txt')?.text.trim() ?? '';

      final blk = anchor.querySelector('span.blk');
      final recommendCount = _extractStatNumber(blk, 'span.ok_num');
      final notRecommendCount = _extractStatNumber(blk, 'span.not_ok_num');
      final commentCount = _extractStatNumber(blk, 'span.comment_num');
      final viewCount = _extractViewCount(blk);

      final date = _extractDate(anchor);

      return BoardPostDto(
        id: id,
        title: title,
        url: url,
        author: author,
        date: date,
        recommendCount: recommendCount,
        notRecommendCount: notRecommendCount,
        commentCount: commentCount,
        viewCount: viewCount,
        thumbnailUrl: thumbnailUrl,
      );
    }).toList();
  }

  static String _extractThumbnail(dom.Element anchor) {
    final img = anchor.querySelector('td img.img');
    if (img == null) return '';
    final src = img.attributes['src'] ?? '';
    if (src.contains('no_image')) return '';
    final normalized = src.startsWith('//') ? 'https:$src' : src;
    return _fullSizeFromThumb(normalized);
  }

  static String _fullSizeFromThumb(String url) {
    final match = RegExp(r'thumb\.php\?url=([^&]+)').firstMatch(url);
    if (match == null) return url;
    var original = Uri.decodeComponent(match.group(1)!);
    final sizeIdx = original.indexOf('?SIZE=');
    if (sizeIdx != -1) original = original.substring(0, sizeIdx);
    if (MediaClassifier.classify(original) == MediaType.video) {
      var thumbUrl = url;
      final outerSizeIdx = thumbUrl.indexOf('?SIZE=');
      if (outerSizeIdx != -1) thumbUrl = thumbUrl.substring(0, outerSizeIdx);
      return thumbUrl;
    }
    return original;
  }

  static int _extractStatNumber(dom.Element? parent, String selector) {
    if (parent == null) return 0;
    final el = parent.querySelector(selector);
    if (el == null) return 0;
    final text = el.text.trim();
    return int.tryParse(text.replaceAll(RegExp('[^0-9]'), '')) ?? 0;
  }

  static int _extractViewCount(dom.Element? blk) {
    if (blk == null) return 0;
    final extras = blk.querySelectorAll('span.extra');
    for (final extra in extras) {
      final text = extra.text.trim();
      final num = int.tryParse(text.replaceAll(RegExp('[^0-9]'), ''));
      if (num != null && num > 0) return num;
    }
    return 0;
  }

  static String _extractDate(dom.Element anchor) {
    final authorDiv = anchor.querySelector('span.nick')?.parent;
    if (authorDiv != null) {
      final extra = authorDiv.querySelector('span.extra');
      if (extra != null) return extra.text.trim();
    }
    return '';
  }

  static String _buildPostUrl(String href) {
    if (href.isEmpty) return '';
    final uri = Uri.tryParse(href);
    if (uri == null) return href;
    final table = uri.queryParameters['table'];
    final number = uri.queryParameters['number'];
    if (table != null && number != null) {
      return '/board/read.html?table=$table&number=$number';
    }
    return href;
  }

  static int _extractCurrentPage(dom.Document doc) {
    final active = doc.querySelector('#pgnum span.o_bd');
    if (active == null) return 0;
    return (int.tryParse(active.text.trim()) ?? 1) - 1;
  }

  static int _extractTotalPage(dom.Document doc) {
    final links = doc.querySelectorAll('#pgnum a.def');
    if (links.isEmpty) return 0;
    var maxPage = 0;
    for (final a in links) {
      final href = a.attributes['href'] ?? '';
      final match = RegExp(r'pg=(\d+)').firstMatch(href);
      if (match != null) {
        maxPage = maxPage > int.parse(match.group(1)!)
            ? maxPage
            : int.parse(match.group(1)!);
      }
    }
    return maxPage + 1;
  }
}
