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
    final comments = _extractComments(doc);

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
      commentCount: comments.length,
      comments: comments,
      community: CommunityId.dogdrip,
    );
  }

  static List<Comment> _extractComments(dom.Document doc) {
    final items = doc.querySelectorAll('div.comment-item');
    return items.map(_parseComment).whereType<Comment>().toList();
  }

  static Comment? _parseComment(dom.Element item) {
    final idStr = item.id.replaceAll('comment_', '');
    final id = int.tryParse(idStr) ?? 0;

    final authorEl = item.querySelector('a[class*="member_"]');
    final author = authorEl?.text.trim() ?? '';

    final contentEl = item.querySelector('.rhymix_content, .xe_content');
    final content = contentEl?.text.trim() ?? '';

    final timeText = item.querySelector('.text-muted')?.text ?? '';
    final date = _parseRelativeTime(timeText) ?? DateTime.now();

    final countEl = item.querySelector('.fa-thumbs-up');
    var recommendCount = 0;
    if (countEl != null) {
      final countSpan = countEl.parent?.querySelector('.count');
      recommendCount = int.tryParse(countSpan?.text.trim() ?? '') ?? 0;
    }

    if (content.isEmpty && author.isEmpty) return null;

    return Comment(
      id: id,
      author: author,
      content: content,
      date: date,
      recommendCount: recommendCount,
      isBest: false,
      replies: const [],
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
    return doc.querySelector('div[class*="document_"]');
  }

  static List<String> _extractImages(dom.Element? content) {
    if (content == null) return [];
    return content
        .querySelectorAll('img')
        .map((img) => img.attributes['src'] ?? '')
        .where((src) => src.isNotEmpty)
        .map((src) => src.startsWith('/') ? 'https://www.dogdrip.net$src' : src)
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
          final fullSrc = src.startsWith('/')
              ? 'https://www.dogdrip.net$src'
              : src;
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
