import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/content_block.dart';
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
    final contentEl = doc.querySelector('.detailTxtDeco01, .bodyCont');

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
      commentCount: 0,
      comments: const [],
      community: CommunityId.bobaedream,
    );
  }

  String _extractTitle(dom.Document doc) {
    final el = doc.querySelector('a.bsubject, .bsubject, h3');
    return htmlClient.textOf(el);
  }

  String _extractAuthor(dom.Document doc) {
    return htmlClient.textOf(doc.querySelector('.author02, .author'));
  }

  List<ContentBlock> _buildBlocks(dom.Element? content) {
    if (content == null) return const [];
    return htmlClient.buildContentBlocks(
      content.children,
      const ContentBlockConfig(community: CommunityId.bobaedream),
      fallbackText: content.text,
    );
  }
}
