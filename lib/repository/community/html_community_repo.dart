import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/repository/community/community_repo.dart';
import 'package:keek_news/service/html_service.dart';

abstract class HtmlCommunityRepo implements CommunityRepo {
  const HtmlCommunityRepo({required this.htmlClient});

  final HtmlService htmlClient;

  String listPath(String page);

  String listRowSelector();

  FeedItem? parseListRow(dom.Element row);

  int get listPageSize;

  String? computeNextPageToken(
    dom.Document doc,
    String currentPage,
    List<FeedItem> items,
  ) {
    if (items.length < listPageSize) return null;
    final next = (int.tryParse(currentPage) ?? 0) + 1;
    return '$next';
  }

  @override
  Future<CommunityListResult> fetchLatest({String? pageToken}) async {
    final page = pageToken ?? '1';
    final html = await htmlClient.get(listPath(page));
    final doc = html_parser.parse(html);
    final items = doc
        .querySelectorAll(listRowSelector())
        .map(parseListRow)
        .whereType<FeedItem>()
        .toList();
    return CommunityListResult(
      items: items,
      pageToken: computeNextPageToken(doc, page, items),
    );
  }
}
