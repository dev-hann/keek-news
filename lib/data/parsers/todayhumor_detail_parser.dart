import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'package:happy_news/domain/entities/community.dart';
import 'package:happy_news/domain/entities/content_block.dart';
import 'package:happy_news/domain/entities/post_detail.dart';

class TodayhumorDetailParser {
  static PostDetail parse(String htmlString) {
    final doc = html_parser.parse(htmlString);

    final id = _extractId(doc);
    final title = _extractTitle(doc);
    final author = _extractAuthor(doc);
    final date = _extractDate(doc);
    final contentEl = doc.querySelector('.viewContent');
    final contentHtml = contentEl?.innerHtml ?? '';
    final imageUrls = _extractImages(contentEl);
    final contentBlocks = _buildBlocks(contentEl);
    final counts = _extractCounts(doc);

    return PostDetail(
      id: id,
      title: title,
      author: author,
      date: date,
      contentHtml: contentHtml,
      contentBlocks: contentBlocks,
      imageUrls: imageUrls,
      recommendCount: counts[0],
      notRecommendCount: 0,
      viewCount: counts[1],
      commentCount: counts[2],
      comments: const [],
      community: CommunityId.todayhumor,
    );
  }

  static int _extractId(dom.Document doc) {
    final body = doc.body?.text ?? '';
    final match = RegExp(r'no=(\d+)').firstMatch(body);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  static String _extractTitle(dom.Document doc) {
    final el = doc.querySelector('.viewSubjectDiv');
    final text = el?.text.trim() ?? '';
    final match = RegExp(
      r'<!--EAP_SUBJECT-->(.*)<!--/EAP_SUBJECT-->',
    ).firstMatch(el?.innerHtml ?? '');
    return match?.group(1)?.trim() ?? text;
  }

  static String _extractAuthor(dom.Document doc) {
    final el = doc.querySelector('#viewPageWriterNameSpan');
    final nameAttr = el?.attributes['name'];
    if (nameAttr != null && nameAttr.isNotEmpty) return nameAttr;
    final b = el?.querySelector('b');
    return b?.text.trim() ?? el?.text.trim() ?? '';
  }

  static DateTime _extractDate(dom.Document doc) {
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

  static List<String> _extractImages(dom.Element? content) {
    if (content == null) return [];
    final urls = <String>[];

    for (final source in content.querySelectorAll('source')) {
      final src = source.attributes['src'] ?? '';
      if (src.isNotEmpty && src.contains('.mp4')) {
        urls.add(src.startsWith('//') ? 'https:$src' : src);
      }
    }

    urls.addAll(
      content
          .querySelectorAll('img')
          .where((img) {
            final src = img.attributes['src'] ?? '';
            return src.contains('todayhumor') || src.startsWith('http');
          })
          .map((img) => img.attributes['src'] ?? '')
          .where((src) => src.isNotEmpty),
    );
    return urls;
  }

  static List<ContentBlock> _buildBlocks(dom.Element? content) {
    if (content == null) return [];
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

  static List<int> _extractCounts(dom.Document doc) {
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
