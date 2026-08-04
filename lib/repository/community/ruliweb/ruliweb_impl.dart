import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:keek_news/model/comment.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/repository/community/html_community_repo.dart';
import 'package:keek_news/service/html_service.dart';

class RuliwebImpl extends HtmlCommunityRepo {
  RuliwebImpl({required super.htmlClient});

  @override
  CommunityId get communityId => CommunityId.ruliweb;

  @override
  String listPath(String page) => '/best/humor?page=$page';

  @override
  String listRowSelector() => 'tr.table_body';

  @override
  int get listPageSize => 30;

  @override
  FeedItem? parseListRow(dom.Element row) {
    final subjectLink = row.querySelector('a.subject_link');
    if (subjectLink == null) return null;

    final href = subjectLink.attributes['href'] ?? '';
    final idMatch = RegExp(r'/read/(\d+)').firstMatch(href);
    if (idMatch == null) return null;
    final id = idMatch.group(1)!;

    final title = subjectLink.text.trim();
    if (title.isEmpty) return null;

    final author = htmlClient.textOf(row.querySelector('.writer, .nick'));

    final replyEl = row.querySelector('.reply_num, .comment_count');
    final commentCount = htmlClient.extractNumber(replyEl?.text ?? '0');

    final recommendEl = row.querySelector('.recommend_num, .symphony_btn');
    final recommendCount = htmlClient.extractNumber(recommendEl?.text ?? '0');

    final hitEl = row.querySelector('.hit, .read_count');
    final viewCount = htmlClient.extractNumber(hitEl?.text ?? '0');

    return FeedItem(
      community: CommunityId.ruliweb,
      id: id,
      title: title,
      url: href,
      author: author.isEmpty ? null : author,
      commentCount: commentCount,
      recommendCount: recommendCount,
      viewCount: viewCount,
    );
  }

  @override
  Future<LoadedPostDetail> fetchDetail(String id) async {
    final html = await htmlClient.get('/best/board/300143/read/$id?m=humor');
    final doc = html_parser.parse(html);
    // .view_content wraps <article><div>...<p/></div></article>. If we hand
    // the outer wrapper to buildContentBlocks it sees a single <article> and
    // flushes every TextBlock (only ImageBlocks survive, since querySelectorAll
    // finds imgs at any depth). Descend to the inner <div> so the <p> tags
    // become direct children.
    final contentEl =
        doc.querySelector('.view_content article div') ??
        doc.querySelector('.view_content') ??
        doc.querySelector('.matter_content');

    return LoadedPostDetail(
      id: int.tryParse(id) ?? 0,
      title: _extractTitle(doc),
      author: _extractAuthor(doc),
      date: DateTime.now(),
      contentHtml: contentEl?.innerHtml ?? '',
      contentBlocks: _buildBlocks(contentEl),
      imageUrls: htmlClient.collectImageUrls(contentEl, community: communityId),
      recommendCount: htmlClient.statOf(doc.body, 'span.like'),
      notRecommendCount: 0,
      viewCount: htmlClient.statOf(doc.body, '.hit'),
      commentCount: _extractCommentCount(doc),
      comments: _extractComments(doc),
      community: CommunityId.ruliweb,
    );
  }

  String _extractTitle(dom.Document doc) {
    final el = doc.querySelector('.subject_text, h1.subject');
    return htmlClient.textOf(el);
  }

  String _extractAuthor(dom.Document doc) {
    return htmlClient.textOf(
      doc.querySelector('.user_info .nick, .writer, .nick'),
    );
  }

  int _extractCommentCount(dom.Document doc) {
    // .comment_count text is "댓글 | 총 91 개" — extractNumber picks the digits.
    return htmlClient.statOf(doc.body, '.comment_count');
  }

  List<ContentBlock> _buildBlocks(dom.Element? content) {
    if (content == null) return const [];
    return htmlClient.buildContentBlocks(
      content.children,
      const ContentBlockConfig(community: CommunityId.ruliweb),
      fallbackText: content.text,
    );
  }

  List<Comment> _extractComments(dom.Document doc) {
    // Ruliweb renders best + normal comments as div.comment in separate
    // containers, and best items mirror a subset of normal ones. Dedup by
    // text content (ids are unreliable — many items carry no id attribute).
    final bestTexts = <String>{};
    for (final best in doc.querySelectorAll('.best .comment')) {
      final txt = htmlClient.textOf(best.querySelector('.text')).trim();
      if (txt.isNotEmpty) bestTexts.add(txt);
    }

    final seen = <String>{};
    final result = <Comment>[];
    for (final item in doc.querySelectorAll('.comment')) {
      final author = htmlClient.textOf(
        item.querySelector('.user_info .nick, .nick, .writer'),
      );
      final content = htmlClient.textOf(item.querySelector('.text')).trim();
      if (content.isEmpty && author.isEmpty) continue;
      if (!seen.add(content)) continue;
      final id = htmlClient.extractNumber(item.id);
      final isBest = bestTexts.contains(content);
      result.add(
        Comment(
          id: id,
          author: author,
          content: content,
          date: DateTime.now(),
          recommendCount: 0,
          isBest: isBest,
          replies: const [],
        ),
      );
    }
    return result;
  }
}
