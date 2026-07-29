import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'package:humoruniv/domain/entities/community.dart';
import 'package:humoruniv/domain/entities/content_block.dart';
import 'package:humoruniv/domain/entities/post_detail.dart';

class PpomppuDetailParser {
  static PostDetail parse(String htmlString) {
    final doc = html_parser.parse(htmlString);

    final title = _extractTitle(doc);
    final author = _extractAuthor(doc);
    final date = _extractDate(doc);
    final contentEl = doc.querySelector('.board-contents');
    final contentHtml = contentEl?.innerHtml ?? '';
    final videoUrls = _extractVideoUrls(contentEl);
    final imageUrls = _extractImages(contentEl);
    final allMediaUrls = [...videoUrls, ...imageUrls];
    final contentBlocks = _buildBlocks(contentEl);
    final viewCount = _extractViewCount(doc);

    final noMatch = RegExp(r'no=(\d+)').firstMatch(doc.body?.text ?? '');

    return PostDetail(
      id: int.tryParse(noMatch?.group(1) ?? '') ?? 0,
      title: title,
      author: author,
      date: date,
      contentHtml: contentHtml,
      contentBlocks: contentBlocks,
      imageUrls: allMediaUrls,
      recommendCount: 0,
      notRecommendCount: 0,
      viewCount: viewCount,
      commentCount: 0,
      comments: const [],
      community: CommunityId.ppomppu,
    );
  }

  static String _extractTitle(dom.Document doc) {
    return doc.querySelector('#topTitle h1')?.text.trim() ?? '';
  }

  static String _extractAuthor(dom.Document doc) {
    final el = doc.querySelector('.topTitle-name a');
    return el?.text.trim() ?? '';
  }

  static DateTime _extractDate(dom.Document doc) {
    final lis = doc.querySelectorAll('#topTitle li');
    for (final li in lis) {
      final text = li.text;
      final match = RegExp(
        r'(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})',
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
    }
    return DateTime.now();
  }

  static List<String> _extractVideoUrls(dom.Element? content) {
    if (content == null) return [];
    final urls = <String>[];

    for (final source in content.querySelectorAll('source')) {
      final src = source.attributes['src'] ?? '';
      if (src.isNotEmpty && src.contains('.mp4')) {
        urls.add(src.startsWith('//') ? 'https:$src' : src);
      }
    }

    return urls.toSet().toList();
  }

  static List<String> _extractImages(dom.Element? content) {
    if (content == null) return [];
    return content
        .querySelectorAll('img')
        .map((img) => img.attributes['src'] ?? '')
        .where((src) => src.isNotEmpty)
        .map((src) => src.startsWith('//') ? 'https:$src' : src)
        .toList();
  }

  static List<ContentBlock> _buildBlocks(dom.Element? content) {
    if (content == null) return [];
    final blocks = <ContentBlock>[];

    for (final p in content.querySelectorAll('p')) {
      final videos = p.querySelectorAll('video');
      if (videos.isNotEmpty) {
        for (final video in videos) {
          final sources = video.querySelectorAll('source');
          for (final source in sources) {
            final src = source.attributes['src'] ?? '';
            if (src.isNotEmpty && src.contains('.mp4')) {
              final fullSrc = src.startsWith('//') ? 'https:$src' : src;
              if (!blocks.any((b) => b is VideoBlock && b.url == fullSrc)) {
                blocks.add(VideoBlock(url: fullSrc));
              }
            }
          }
        }
        continue;
      }

      final imgs = p.querySelectorAll('img');
      if (imgs.isNotEmpty) {
        for (final img in imgs) {
          final src = img.attributes['src'] ?? '';
          if (src.isNotEmpty) {
            final fullSrc = src.startsWith('//') ? 'https:$src' : src;
            blocks.add(ImageBlock(url: fullSrc));
          }
        }
      } else {
        final text = p.text.trim();
        if (text.isNotEmpty &&
            !text.contains('browser does not support') &&
            !text.contains('브라우저') &&
            text != '\u00a0') {
          blocks.add(TextBlock(text));
        }
      }
    }

    return blocks;
  }

  static int _extractViewCount(dom.Document doc) {
    final lis = doc.querySelectorAll('#topTitle li');
    for (final li in lis) {
      final match = RegExp(r'조회수\s*(\d+)').firstMatch(li.text);
      if (match != null) return int.parse(match.group(1)!);
    }
    return 0;
  }
}
