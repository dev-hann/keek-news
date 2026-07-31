import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:keek_news/model/comment.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/repository/community_repo.dart';
import 'package:keek_news/repository/dogdrip/dogdrip_repo.dart';
import 'package:keek_news/service/html_service.dart';
import 'package:keek_news/utils/media_classifier.dart';
import 'package:keek_news/utils/media_dedup.dart';
import 'package:keek_news/utils/url_builder.dart';

class DogdripImpl implements DogdripRepo {
  DogdripImpl({required this.htmlClient});

  final HtmlService htmlClient;

  @override
  CommunityId get communityId => CommunityId.dogdrip;

  @override
  Future<CommunityListResult> fetchLatest({String? pageToken}) async {
    try {
      final page = pageToken ?? '1';
      final html = await htmlClient.get('/index.php?mid=dogdrip&page=$page');
      final doc = html_parser.parse(html);
      final items = doc
          .querySelectorAll('li.webzine')
          .map(_parseListRow)
          .whereType<FeedItem>()
          .toList();
      final nextPage = (int.tryParse(page) ?? 0) + 1;
      return CommunityListResult(
        items: items,
        pageToken: items.length >= 5 ? '$nextPage' : null,
      );
    } on ServerFailure {
      rethrow;
    } on NetworkFailure {
      rethrow;
    } catch (e) {
      debugPrint('DogdripImpl fetchLatest error: $e');
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<PostDetail> fetchDetail(String id) async {
    try {
      final html = await htmlClient.get('/$id');
      final doc = html_parser.parse(html);
      final contentEl = _findContent(doc);

      return PostDetail(
        id: int.tryParse(id) ?? 0,
        title: _extractTitle(doc),
        author: _extractAuthor(doc),
        date: DateTime.now(),
        contentHtml: contentEl?.innerHtml ?? '',
        contentBlocks: _buildBlocks(contentEl),
        imageUrls: _extractImages(contentEl),
        recommendCount: 0,
        notRecommendCount: 0,
        viewCount: 0,
        commentCount: _extractCommentCount(doc),
        comments: _extractComments(doc),
        community: CommunityId.dogdrip,
      );
    } on ServerFailure {
      rethrow;
    } on NetworkFailure {
      rethrow;
    } catch (e) {
      debugPrint('DogdripImpl fetchDetail error: $e');
      throw ServerFailure(e.toString());
    }
  }

  FeedItem? _parseListRow(dom.Element row) {
    final titleLink = row.querySelector('a.title-link');
    if (titleLink == null) return null;
    final id = htmlClient.attrOf(titleLink, 'data-document-srl') ?? '';
    if (id.isEmpty) return null;

    final url = htmlClient.attrOf(titleLink, 'href') ?? '';
    final title = titleLink.text.trim();
    final author = htmlClient.textOf(row.querySelector('a[class*="member_"]'));

    final metaDiv = row.querySelector('div.ed.flex.list-meta');
    final recommendText = metaDiv?.querySelector('span.text-primary')?.text;
    final recommendCount = int.tryParse((recommendText ?? '').trim()) ?? 0;

    final timeText = metaDiv?.text ?? '';
    final publishedAt = _parseRelativeTime(timeText);

    final thumbnail = row.querySelector('img.webzine-thumbnail');
    final thumbSrc = htmlClient.attrOf(thumbnail, 'src');

    String? thumbnailUrl;
    if (thumbSrc != null && thumbSrc.isNotEmpty) {
      thumbnailUrl = thumbSrc.startsWith('/')
          ? 'https://www.dogdrip.net$thumbSrc'
          : thumbSrc;
    }

    return FeedItem(
      community: CommunityId.dogdrip,
      id: id,
      title: title,
      url: url,
      author: author.isEmpty ? null : author,
      publishedAt: publishedAt,
      recommendCount: recommendCount,
      thumbnailUrl: thumbnailUrl,
    );
  }

  DateTime? _parseRelativeTime(String text) {
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

  String _extractTitle(dom.Document doc) {
    final h4 = doc.querySelector('h4 a.ed');
    if (h4 != null) return h4.text.trim();
    return htmlClient.textOf(doc.querySelector('h1'));
  }

  String _extractAuthor(dom.Document doc) {
    return htmlClient.textOf(doc.querySelector('a[class*="member_"]'));
  }

  dom.Element? _findContent(dom.Document doc) {
    return doc.querySelector('div[class*="document_"]');
  }

  int _extractCommentCount(dom.Document doc) {
    final match = RegExp(r'(\d+)\s*개의\s*댓글').firstMatch(doc.body?.text ?? '');
    return match != null ? int.parse(match.group(1)!) : 0;
  }

  List<String> _extractImages(dom.Element? content) {
    if (content == null) return const [];
    return content
        .querySelectorAll('img')
        .map((img) => img.attributes['src'] ?? '')
        .where((src) => src.isNotEmpty)
        .map((src) {
          if (src.startsWith('//')) return 'https:$src';
          if (src.startsWith('/')) return 'https://www.dogdrip.net$src';
          return src;
        })
        .where(MediaClassifier.isLoadableImage)
        .toList();
  }

  List<ContentBlock> _buildBlocks(dom.Element? content) {
    if (content == null) return const [];
    final blocks = <ContentBlock>[];
    final seenVideoKeys = <String>{};

    for (final child in content.children) {
      final videos = <dom.Element>[
        if (child.localName == 'video') child,
        ...child.querySelectorAll('video'),
      ];
      if (videos.isNotEmpty) {
        for (final video in videos) {
          if (_addVideo(blocks, video, seenVideoKeys)) break;
        }
        continue;
      }

      final imgs = <dom.Element>[
        if (child.localName == 'img') child,
        ...child.querySelectorAll('img'),
      ];
      if (imgs.isNotEmpty) {
        for (final img in imgs) {
          final src = img.attributes['src'] ?? '';
          if (src.isNotEmpty) {
            blocks.add(ImageBlock(url: _resolveMedia(src)));
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

  bool _addVideo(
    List<ContentBlock> blocks,
    dom.Element video,
    Set<String> seenKeys,
  ) {
    final directSrc = video.attributes['src'] ?? '';
    final mp4Src = (directSrc.isNotEmpty && directSrc.contains('.mp4'))
        ? directSrc
        : (video
              .querySelectorAll('source')
              .map((s) => s.attributes['src'] ?? '')
              .firstWhere(
                (s) => s.isNotEmpty && s.contains('.mp4'),
                orElse: () => '',
              ));
    if (mp4Src.isEmpty) return false;
    final full = _resolveMedia(mp4Src);
    if (!seenKeys.add(MediaDedup.filenameKey(full))) return false;
    final poster = video.attributes['poster'] ?? '';
    blocks.add(
      VideoBlock(
        url: full,
        thumbnailUrl: poster.isNotEmpty ? _resolveMedia(poster) : null,
      ),
    );
    return true;
  }

  String _resolveMedia(String src) {
    if (src.startsWith('//')) return 'https:$src';
    if (src.startsWith('/')) return 'https://www.dogdrip.net$src';
    return src;
  }

  List<Comment> _extractComments(dom.Document doc) {
    final items = doc.querySelectorAll('div.comment-item');
    return items.map(_parseComment).whereType<Comment>().toList();
  }

  Comment? _parseComment(dom.Element item) {
    final idStr = item.id.replaceAll('comment_', '');
    final id = int.tryParse(idStr) ?? 0;
    final author = htmlClient.textOf(item.querySelector('a[class*="member_"]'));
    final contentEl = item.querySelector('.rhymix_content, .xe_content');
    final content = htmlClient.textOf(contentEl);

    final timeText = item.querySelector('.text-muted')?.text ?? '';
    final date = _parseRelativeTime(timeText) ?? DateTime.now();

    var recommendCount = 0;
    final countEl = item.querySelector('.fa-thumbs-up');
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
      mediaBlocks: _extractCommentMedia(contentEl),
    );
  }

  List<ContentBlock> _extractCommentMedia(dom.Element? contentEl) {
    if (contentEl == null) return const [];
    final media = <ContentBlock>[];
    for (final img in contentEl.querySelectorAll('img')) {
      final src = img.attributes['src'] ?? '';
      if (src.isEmpty) continue;
      media.add(ImageBlock(url: UrlBuilder.resolveAbsolute(communityId, src)));
    }
    return media;
  }
}
