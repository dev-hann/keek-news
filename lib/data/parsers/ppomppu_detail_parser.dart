import 'dart:convert';

import 'package:happy_news/core/utils/media_classifier.dart';
import 'package:happy_news/domain/entities/comment.dart';
import 'package:happy_news/domain/entities/community.dart';
import 'package:happy_news/domain/entities/content_block.dart';
import 'package:happy_news/domain/entities/post_detail.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

class PpomppuDetailParser {
  static PostDetail parse(String htmlString) {
    final doc = html_parser.parse(htmlString);

    final title = _extractTitle(doc);
    final author = _extractAuthor(doc);
    final date = _extractDate(doc);
    final contentEl = doc.querySelector('.board-contents');
    final contentHtml = contentEl?.innerHtml ?? '';
    final imageUrls = _extractImages(contentEl);
    final contentBlocks = _buildBlocks(contentEl);
    final viewCount = _extractViewCount(doc);
    final commentData = _extractCommentData(doc);
    final comments = _extractComments(commentData, date);

    final noMatch = RegExp(r'no=(\d+)').firstMatch(doc.body?.text ?? '');

    return PostDetail(
      id: int.tryParse(noMatch?.group(1) ?? '') ?? 0,
      title: title,
      author: author,
      date: date,
      contentHtml: contentHtml,
      contentBlocks: contentBlocks,
      imageUrls: imageUrls,
      recommendCount: 0,
      notRecommendCount: 0,
      viewCount: viewCount,
      commentCount: _extractCommentCount(commentData),
      comments: comments,
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

  static List<String> _extractImages(dom.Element? content) {
    if (content == null) return [];
    return content
        .querySelectorAll('img')
        .map((img) => img.attributes['src'] ?? '')
        .where((src) => src.isNotEmpty)
        .map((src) => src.startsWith('//') ? 'https:$src' : src)
        .where(MediaClassifier.isLoadableImage)
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

  static Map<String, dynamic>? _extractCommentData(dom.Document doc) {
    final match = RegExp(
      r'initialCommentData\s*=\s*(\{.*\})\s*;',
      dotAll: true,
    ).firstMatch(doc.outerHtml);
    if (match == null) return null;
    try {
      final decoded = jsonDecode(match.group(1)!) as Map<String, dynamic>;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  static int _extractCommentCount(Map<String, dynamic>? data) {
    if (data == null) return 0;
    return (data['total_comment'] as num?)?.toInt() ?? 0;
  }

  static List<Comment> _extractComments(
    Map<String, dynamic>? data,
    DateTime postDate,
  ) {
    if (data == null) return const [];
    final raw = data['comments'];
    if (raw is! List) return const [];

    final result = <Comment>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) continue;

      final id = (item['no'] as num?)?.toInt() ?? 0;
      final author = _stripTags(item['name'] as String? ?? '');
      final content = _stripTags(item['memo'] as String? ?? '');
      final voteBtn = item['vote_btn'];
      final recommend = voteBtn is Map<String, dynamic>
          ? (voteBtn['vote_count'] as num?)?.toInt() ?? 0
          : 0;
      final time = (item['meta'] is Map<String, dynamic>)
          ? (item['meta']!['time_display'] as String?)
          : null;

      result.add(
        Comment(
          id: id,
          author: author,
          content: content,
          date: _mergeTime(postDate, time),
          recommendCount: recommend,
          isBest: false,
          replies: const [],
        ),
      );
    }
    return result;
  }

  static String _stripTags(String html) {
    final text = html_parser.parseFragment(html).text ?? '';
    return text.replaceAll('\u00a0', ' ').trim();
  }

  static DateTime _mergeTime(DateTime base, String? time) {
    if (time == null) return base;
    final match = RegExp(r'(\d{2}):(\d{2}):(\d{2})').firstMatch(time);
    if (match == null) return base;
    return DateTime(
      base.year,
      base.month,
      base.day,
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }
}
