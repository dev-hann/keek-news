import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:keek_news/model/comment.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/repository/community/html_community_repo.dart';
import 'package:keek_news/service/html_service.dart';

class NatepannImpl extends HtmlCommunityRepo {
  NatepannImpl({required super.htmlClient});

  @override
  CommunityId get communityId => CommunityId.natepann;

  @override
  String listPath(String page) => '/talk?page=$page';

  @override
  String listRowSelector() => '.talkmain dl';

  @override
  int get listPageSize => 20;

  @override
  FeedItem? parseListRow(dom.Element row) {
    final titleLink = row.querySelector('dd.tit a');
    if (titleLink == null) return null;

    final href = titleLink.attributes['href'] ?? '';
    final idMatch = RegExp(r'/talk/(\d+)').firstMatch(href);
    if (idMatch == null) return null;
    final id = idMatch.group(1)!;

    final title = titleLink.text.trim();
    if (title.isEmpty) return null;

    final author = htmlClient.textOf(row.querySelector('a.writer'));

    final thumbImg = row.querySelector('dd.thumb img');
    final thumbSrc = htmlClient.attrOf(thumbImg, 'src');
    final thumbnailUrl = (thumbSrc != null && thumbSrc.isNotEmpty)
        ? thumbSrc
        : null;

    return FeedItem(
      community: CommunityId.natepann,
      id: id,
      title: title,
      url: href,
      author: author.isEmpty ? null : author,
      thumbnailUrl: thumbnailUrl,
    );
  }

  @override
  Future<LoadedPostDetail> fetchDetail(String id) async {
    final html = await htmlClient.get('/talk/$id');
    final doc = html_parser.parse(html);
    final contentEl = doc.querySelector('.espresso_editor_view, #contentArea');

    return LoadedPostDetail(
      id: int.tryParse(id) ?? 0,
      title: _extractTitle(doc),
      author: _extractAuthor(doc),
      date: DateTime.now(),
      contentHtml: contentEl?.innerHtml ?? '',
      contentBlocks: _buildBlocks(contentEl),
      imageUrls: htmlClient.collectImageUrls(contentEl, community: communityId),
      recommendCount: _extractRecommend(doc),
      notRecommendCount: 0,
      viewCount: _extractViewCount(doc),
      commentCount: _extractCommentCount(doc),
      comments: _extractComments(doc),
      community: CommunityId.natepann,
    );
  }

  String _extractTitle(dom.Document doc) {
    return htmlClient.textOf(
      doc.querySelector('.post-title, h1, h2.tit, h3.tit, .view_tit'),
    );
  }

  String _extractAuthor(dom.Document doc) {
    return htmlClient.textOf(doc.querySelector('.writer, .nick, .user_info'));
  }

  int _extractRecommend(dom.Document doc) {
    return htmlClient.statOf(doc.body, '.reco_num, .good_count');
  }

  int _extractViewCount(dom.Document doc) {
    return htmlClient.statOf(doc.body, '.read_num, .view_count');
  }

  int _extractCommentCount(dom.Document doc) {
    return htmlClient.statOf(doc.body, '.cmt_count, .reply_count');
  }

  List<ContentBlock> _buildBlocks(dom.Element? content) {
    if (content == null) return const [];
    return htmlClient.buildContentBlocks(
      content.children,
      const ContentBlockConfig(community: CommunityId.natepann),
      fallbackText: content.text,
    );
  }

  List<Comment> _extractComments(dom.Document doc) {
    final items = doc.querySelectorAll('.cmt_post, .comment_item, li.comment');
    return items.map(_parseComment).whereType<Comment>().toList();
  }

  Comment? _parseComment(dom.Element item) {
    final author = htmlClient.textOf(item.querySelector('.writer, .nick'));
    final content = htmlClient.textOf(
      item.querySelector('.cmt_txt, .text, .comment_text'),
    );
    if (content.isEmpty && author.isEmpty) return null;

    final id = htmlClient.extractNumber(item.id);

    return Comment(
      id: id,
      author: author,
      content: content,
      date: DateTime.now(),
      recommendCount: 0,
      isBest: false,
      replies: const [],
    );
  }
}
