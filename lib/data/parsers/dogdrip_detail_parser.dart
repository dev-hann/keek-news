import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'package:humoruniv/domain/entities/comment.dart';
import 'package:humoruniv/domain/entities/community.dart';
import 'package:humoruniv/domain/entities/content_block.dart';
import 'package:humoruniv/domain/entities/post_detail.dart';

class DogdripDetailParser {
  static PostDetail parse(String htmlString) {
    final doc = html_parser.parse(htmlString);

    final id = _extractId(doc);
    final title = _extractTitle(doc);
    final author = _extractAuthor(doc);
    final contentEl = _findContent(doc);
    final contentHtml = contentEl?.innerHtml ?? '';
    final imageUrls = _extractImages(contentEl);
    final contentBlocks = _buildBlocks(contentEl);

    return PostDetail(
      id: id,
      title: title,
      author: author,
      date: DateTime.now(),
      contentHtml: contentHtml,
      contentBlocks: contentBlocks,
      imageUrls: imageUrls,
      recommendCount: 0,
      notRecommendCount: 0,
      viewCount: 0,
      commentCount: 0,
      comments: const [],
      community: CommunityId.dogdrip,
    );
  }

  static int _extractId(dom.Document doc) {
    final body = doc.body?.innerHtml ?? '';
    final match = RegExp(r'document_([\d]+)').firstMatch(body);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  static String _extractTitle(dom.Document doc) {
    final h4 = doc.querySelector('h4 a.ed');
    if (h4 != null) return h4.text.trim();
    final h1 = doc.querySelector('h1');
    return h1?.text.trim() ?? '';
  }

  static String _extractAuthor(dom.Document doc) {
    final el = doc.querySelector('a[class*="member_"]');
    return el?.text.trim() ?? '';
  }

  static dom.Element? _findContent(dom.Document doc) {
    return doc.querySelector('.rhymix_content') ??
        doc.querySelector('.xe_content');
  }

  static List<String> _extractImages(dom.Element? content) {
    if (content == null) return [];
    return content
        .querySelectorAll('img')
        .map((img) => img.attributes['src'] ?? '')
        .where((src) => src.isNotEmpty)
        .map((src) =>
            src.startsWith('/') ? 'https://www.dogdrip.net$src' : src)
        .toList();
  }

  static List<ContentBlock> _buildBlocks(dom.Element? content) {
    if (content == null) return [];
    final blocks = <ContentBlock>[];

    for (final p in content.querySelectorAll('p')) {
      final imgs = p.querySelectorAll('img');
      for (final img in imgs) {
        final src = img.attributes['src'] ?? '';
        if (src.isNotEmpty) {
          final fullSrc =
              src.startsWith('/') ? 'https://www.dogdrip.net$src' : src;
          blocks.add(ImageBlock(url: fullSrc));
        }
      }
      if (imgs.isEmpty && p.text.trim().isNotEmpty) {
        blocks.add(TextBlock(p.text.trim()));
      }
    }

    return blocks;
  }
}
