import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'package:humoruniv/domain/entities/community.dart';
import 'package:humoruniv/domain/entities/content_block.dart';
import 'package:humoruniv/domain/entities/post_detail.dart';

class FmkoreaDetailParser {
  static PostDetail parse(String htmlString) {
    final doc = html_parser.parse(htmlString);

    final id = _extractId(doc);
    final title = _extractTitle(doc);
    final author = _extractAuthor(doc);
    final date = _extractDate(doc);
    final contentEl = _findContent(doc);
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
      community: CommunityId.fmkorea,
    );
  }

  static int _extractId(dom.Document doc) {
    final body = doc.body?.innerHtml ?? '';
    final match = RegExp(r'document_([\d]+)').firstMatch(body);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  static String _extractTitle(dom.Document doc) {
    final span = doc.querySelector('.np_18px_span');
    if (span != null) return span.text.trim();
    final h1 = doc.querySelector('h1.np_18px');
    return h1?.text.trim() ?? '';
  }

  static String _extractAuthor(dom.Document doc) {
    final el = doc.querySelector('a.member_plate');
    return el?.text.trim() ?? '';
  }

  static DateTime _extractDate(dom.Document doc) {
    final dateEl = doc.querySelector('span.date');
    final text = dateEl?.text ?? '';
    final match = RegExp(
      r'(\d{4})\.(\d{2})\.(\d{2})\s+(\d{2}):(\d{2})',
    ).firstMatch(text);
    if (match != null) {
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        int.parse(match.group(4)!),
        int.parse(match.group(5)!),
      );
    }
    return DateTime.now();
  }

  static dom.Element? _findContent(dom.Document doc) {
    final candidates = doc.querySelectorAll('[class*="document_"][class*="xe_content"]');
    for (final el in candidates) {
      if (el.innerHtml.length > 50) return el;
    }
    return doc.querySelector('.xe_content');
  }

  static List<String> _extractImages(dom.Element? content) {
    if (content == null) return [];
    return content
        .querySelectorAll('img')
        .map((img) => img.attributes['src'] ?? '')
        .where((src) => src.isNotEmpty && !src.contains('transparent.gif'))
        .map((src) => src.startsWith('//') ? 'https:$src' : src)
        .toList();
  }

  static List<ContentBlock> _buildBlocks(dom.Element? content) {
    if (content == null) return [];
    final blocks = <ContentBlock>[];

    for (final div in content.querySelectorAll('div')) {
      final imgs = div.querySelectorAll('img');
      final videos = div.querySelectorAll('video source');

      for (final v in videos) {
        final src = v.attributes['src'] ?? '';
        if (src.isNotEmpty) {
          final fullSrc = src.startsWith('//') ? 'https:$src' : src;
          blocks.add(VideoBlock(url: fullSrc));
        }
      }

      for (final img in imgs) {
        final src = img.attributes['src'] ?? '';
        if (src.isNotEmpty && !src.contains('transparent.gif')) {
          final fullSrc = src.startsWith('//') ? 'https:$src' : src;
          blocks.add(ImageBlock(url: fullSrc));
        }
      }

      if (imgs.isEmpty && videos.isEmpty && div.text.trim().isNotEmpty) {
        final text = div.text.trim();
        if (text.isNotEmpty && !blocks.any((b) => b is TextBlock && b.text == text)) {
          blocks.add(TextBlock(text));
        }
      }
    }

    return blocks;
  }

  static List<int> _extractCounts(dom.Document doc) {
    final btmArea = doc.querySelector('.btm_area');
    final text = btmArea?.text ?? '';

    final voteMatch = RegExp(r'추천\s*수\s*<b>(\d+)</b>').firstMatch(text);
    final viewMatch = RegExp(r'조회\s*수\s*<b>(\d+)</b>').firstMatch(text);
    final commentMatch = RegExp(r'댓글\s*<b>(\d+)</b>').firstMatch(text);

    final plainText = btmArea?.text ?? '';
    final voteMatch2 = RegExp(r'추천 수 (\d+)').firstMatch(plainText);
    final viewMatch2 = RegExp(r'조회 수 (\d+)').firstMatch(plainText);
    final commentMatch2 = RegExp(r'댓글 (\d+)').firstMatch(plainText);

    return [
      int.tryParse(voteMatch?.group(1) ?? voteMatch2?.group(1) ?? '') ?? 0,
      int.tryParse(viewMatch?.group(1) ?? viewMatch2?.group(1) ?? '') ?? 0,
      int.tryParse(commentMatch?.group(1) ?? commentMatch2?.group(1) ?? '') ?? 0,
    ];
  }
}
