import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:keek_news/model/comment.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/model/url_builder.dart';
import 'package:keek_news/repository/community/html_community_repo.dart';
import 'package:keek_news/service/html_service.dart';

class DogdripImpl extends HtmlCommunityRepo {
  DogdripImpl({required super.htmlClient});

  @override
  CommunityId get communityId => CommunityId.dogdrip;

  @override
  String listPath(String page) => '/index.php?mid=dogdrip&page=$page';

  @override
  String listRowSelector() => 'li.webzine';

  @override
  int get listPageSize => 5;

  @override
  Future<LoadedPostDetail> fetchDetail(String id) async {
    final html = await htmlClient.get('/$id');
    final doc = html_parser.parse(html);
    final contentEl = _findContent(doc);

    return LoadedPostDetail(
      id: int.tryParse(id) ?? 0,
      title: _extractTitle(doc),
      author: _extractAuthor(doc),
      date: DateTime.now(),
      contentHtml: contentEl?.innerHtml ?? '',
      contentBlocks: _buildBlocks(contentEl),
      imageUrls: htmlClient.collectImageUrls(contentEl, community: communityId),
      recommendCount: 0,
      notRecommendCount: 0,
      viewCount: 0,
      commentCount: _extractCommentCount(doc),
      comments: _extractComments(doc),
      community: CommunityId.dogdrip,
    );
  }

  @override
  FeedItem? parseListRow(dom.Element row) {
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

    final thumbnailUrl = (thumbSrc == null || thumbSrc.isEmpty)
        ? null
        : UrlBuilder.resolveAbsolute(communityId, thumbSrc);

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

  List<ContentBlock> _buildBlocks(dom.Element? content) {
    if (content == null) return const [];
    return htmlClient.buildContentBlocks(
      content.children,
      const ContentBlockConfig(community: CommunityId.dogdrip),
      fallbackText: content.text,
    );
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
