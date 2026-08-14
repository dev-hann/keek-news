import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:keek_news/model/comment.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/repository/community/html_community_repo.dart';
import 'package:keek_news/service/html_service.dart';

class BobaedreamImpl extends HtmlCommunityRepo {
  BobaedreamImpl({required super.htmlClient});

  @override
  CommunityId get communityId => CommunityId.bobaedream;

  @override
  String listPath(String page) => '/list?code=humor&page=$page';

  @override
  String listRowSelector() => '.clistTable02 tbody tr';

  @override
  int get listPageSize => 30;

  @override
  FeedItem? parseListRow(dom.Element row) {
    final titleLink = row.querySelector('a.bsubject');
    if (titleLink == null) return null;

    final href = titleLink.attributes['href'] ?? '';
    final no = htmlClient.extractQueryParam(href, 'No');
    if (no == null || no.isEmpty) return null;

    final title = titleLink.text.trim();
    if (title.isEmpty) return null;

    final author = htmlClient.textOf(row.querySelector('td.author02'));

    final commentEl = row.querySelector('.totreply');
    final commentCount = htmlClient.extractNumber(commentEl?.text ?? '0');

    final tds = row.querySelectorAll('td');
    var viewCount = 0;
    var recommendCount = 0;
    if (tds.length >= 6) {
      recommendCount = htmlClient.extractNumber(tds[4].text);
      viewCount = htmlClient.extractNumber(tds[5].text);
    }

    return FeedItem(
      community: CommunityId.bobaedream,
      id: no,
      title: title,
      url: '/view?code=humor&No=$no',
      author: author.isEmpty ? null : author,
      commentCount: commentCount,
      recommendCount: recommendCount,
      viewCount: viewCount,
    );
  }

  @override
  Future<LoadedPostDetail> fetchDetail(String id) async {
    final html = await htmlClient.get('/view?code=humor&No=$id');
    final doc = html_parser.parse(html);
    // .detailTxtDeco01 is a hit-counter badge rendered before the real body;
    // .bodyCont holds the actual <p>/<img> content. Selecting .detailTxtDeco01
    // first used to mask the real body entirely.
    final contentEl = doc.querySelector('.bodyCont');
    final countGroup = htmlClient.textOf(doc.querySelector('.countGroup'));

    return LoadedPostDetail(
      id: int.tryParse(id) ?? 0,
      title: _extractTitle(doc),
      author: _extractAuthor(doc),
      date: _extractDate(countGroup) ?? DateTime.fromMillisecondsSinceEpoch(0),
      contentBlocks: buildBlocks(contentEl),
      imageUrls: htmlClient.collectImageUrls(contentEl, community: communityId),
      recommendCount: _parseInt(countGroup, r'추천\s*([\d,]+)'),
      notRecommendCount: 0,
      viewCount: _parseInt(countGroup, r'조회\s*([\d,]+)'),
      commentCount: _extractCommentCount(doc),
      comments: _extractComments(doc),
      community: CommunityId.bobaedream,
    );
  }

  /// Title on bobaedream detail pages is not in a stable dedicated element;
  /// the page <title> tag is "post title | 보배드림 ...". Strip the suffix.
  String _extractTitle(dom.Document doc) {
    final raw = htmlClient.textOf(doc.querySelector('title'));
    if (raw.isEmpty) return '';
    final pipe = raw.indexOf(' | ');
    return (pipe > 0 ? raw.substring(0, pipe) : raw).trim();
  }

  String _extractAuthor(dom.Document doc) {
    return htmlClient.textOf(doc.querySelector('.nickName, .name, .author'));
  }

  DateTime? _extractDate(String countGroup) {
    return parseDatePattern(
      countGroup,
      RegExp(r'(\d{4})\.(\d{2})\.(\d{2})'),
    );
  }

  int _parseInt(String text, String pattern) {
    final m = RegExp(pattern).firstMatch(text);
    if (m == null) return 0;
    return int.tryParse(m.group(1)!.replaceAll(',', '')) ?? 0;
  }

  int _extractCommentCount(dom.Document doc) {
    final els = doc.querySelectorAll('[id^="small_cmt_"]');
    if (els.isNotEmpty) return els.length;
    final m = RegExp(r'댓글\s*\((\d+)\)').firstMatch(doc.body?.text ?? '');
    return m == null ? 0 : int.tryParse(m.group(1)!) ?? 0;
  }

  /// Comments are wrapped in <dl> elements, each containing the comment text
  /// inside <dd id="small_cmt_<id>"> and the author in .nickName/.name/.author.
  List<Comment> _extractComments(dom.Document doc) {
    final result = <Comment>[];
    for (final textEl in doc.querySelectorAll('[id^="small_cmt_"]')) {
      final dl = textEl.parent?.parent;
      if (dl == null) continue;
      final author = htmlClient.textOf(
        dl.querySelector('.nickName, .name, .author'),
      );
      final content = htmlClient.textOf(textEl);
      if (content.isEmpty && author.isEmpty) continue;
      final id = htmlClient.extractNumber(textEl.id);
      result.add(
        Comment(
          id: id,
          author: author,
          content: content,
          date: DateTime.fromMillisecondsSinceEpoch(0),
          recommendCount: 0,
          isBest: false,
          replies: const [],
        ),
      );
    }
    return result;
  }
}
