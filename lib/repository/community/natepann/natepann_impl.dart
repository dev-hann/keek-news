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
    // Prefer #espresso_editor_view (the real content wrapper whose direct
    // children are the <p> tags). Fall back to #contentArea for older posts
    // that lack the editor wrapper. Note: the editor wrapper uses id, not
    // class, so a single querySelector('#espresso_editor_view, #contentArea')
    // would pick the outer #contentArea first (document order) and yield a
    // single wrapper div — losing all text blocks.
    final contentEl =
        doc.querySelector('#espresso_editor_view') ??
        doc.querySelector('#contentArea');
    final comments = _extractComments(doc);

    return LoadedPostDetail(
      id: int.tryParse(id) ?? 0,
      title: _extractTitle(doc),
      author: _extractAuthor(doc),
      date: DateTime.now(),
      contentHtml: contentEl?.innerHtml ?? '',
      contentBlocks: _buildBlocks(contentEl),
      imageUrls: htmlClient.collectImageUrls(contentEl, community: communityId),
      recommendCount: _extractStat(doc, '추천'),
      notRecommendCount: _extractStat(doc, '반대'),
      viewCount: _extractStat(doc, '조회'),
      commentCount: comments.length,
      comments: comments,
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

  // natepann renders the post stats (조회/추천수/반대수) as sibling
  // <span class="count"> elements distinguished only by an inner label
  // (<span class="tit">조회</span> or <em>추천수</em>). A single CSS selector
  // cannot tell them apart, so scan all .count spans and return the number
  // held by the one whose text contains [label].
  int _extractStat(dom.Document doc, String label) {
    for (final el in doc.querySelectorAll('.count')) {
      final text = htmlClient.textOf(el);
      if (text.contains(label)) {
        return htmlClient.extractNumber(text);
      }
    }
    return 0;
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
    // natepann renders best comments (inside .cmt_best) and the full thread
    // (inside .cmt_list) separately. The .cmt_list items carry the real id
    // attribute; best items do not, so we anchor on the normal list and flag
    // each comment as best if its text also appears in .cmt_best.
    final bestTexts = <String>{};
    for (final best in doc.querySelectorAll('.cmt_best dl.cmt_item')) {
      final txt = htmlClient.textOf(best.querySelector('.usertxt')).trim();
      if (txt.isNotEmpty) bestTexts.add(txt);
    }

    final result = <Comment>[];
    for (final item in doc.querySelectorAll('.cmt_list dl.cmt_item')) {
      final comment = _parseComment(
        item,
        isBest: bestTexts.contains(
          htmlClient.textOf(item.querySelector('.usertxt')).trim(),
        ),
      );
      if (comment != null) result.add(comment);
    }
    return result;
  }

  Comment? _parseComment(dom.Element item, {required bool isBest}) {
    final author = htmlClient.textOf(
      item.querySelector('.nameui, .writer, .nick'),
    );
    // .usertxt wraps an optional <img> + the actual <span>text</span>.
    final content = htmlClient.textOf(item.querySelector('.usertxt'));
    if (content.isEmpty && author.isEmpty) return null;

    final id = htmlClient.extractNumber(item.id);
    final recommend = htmlClient.statOf(item, '.n_good');

    return Comment(
      id: id,
      author: author,
      content: content,
      date: _extractCommentDate(item) ?? DateTime.now(),
      recommendCount: recommend,
      isBest: isBest,
      replies: const [],
    );
  }

  DateTime? _extractCommentDate(dom.Element item) {
    // natepann wraps the timestamp in <i>2026.07.28 12:55</i>.
    final text = item.querySelector('i')?.text.trim() ?? '';
    final match = RegExp(
      r'(\d{4})\.(\d{2})\.(\d{2})\s*(\d{2}):(\d{2})',
    ).firstMatch(text);
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
    );
  }
}
