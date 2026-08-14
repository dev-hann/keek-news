import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:keek_news/model/content_block.dart';
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

  /// Per-community config for [buildBlocks]. Defaults to a plain config for
  /// [communityId]; override only when a community needs special handling
  /// (ppomppu, todayhumor).
  ContentBlockConfig get contentBlockConfig =>
      ContentBlockConfig(community: communityId);

  /// Element feed handed to buildContentBlocks. Defaults to direct children;
  /// ppomppu overrides to `p` descendants.
  List<dom.Element> selectBlockElements(dom.Element content) =>
      content.children;

  /// Whether buildBlocks passes the container's text as fallbackText when no
  /// blocks are produced. Disabled by ppomppu (its `p` selection makes the
  /// whole-container fallback undesirable).
  bool get blockFallbackText => true;

  List<ContentBlock> buildBlocks(dom.Element? content) {
    if (content == null) return const [];
    return htmlClient.buildContentBlocks(
      selectBlockElements(content),
      contentBlockConfig,
      fallbackText: blockFallbackText ? content.text : null,
    );
  }

  String? computeNextPageToken(
    dom.Document doc,
    String currentPage,
    List<FeedItem> items,
  ) {
    if (items.length < listPageSize) return null;
    final next = (int.tryParse(currentPage) ?? 0) + 1;
    return '$next';
  }

  /// Builds a DateTime from the first regex match on [text]. Capture groups
  /// map to year, month, day, then optionally hour/minute/second; missing or
  /// null groups become 0. Two-digit years resolve against 2000 when [year2]
  /// is set. Returns null when the pattern does not match.
  DateTime? parseDatePattern(
    String text,
    RegExp pattern, {
    bool year2 = false,
  }) {
    final m = pattern.firstMatch(text);
    if (m == null) return null;
    int g(int i) => m.group(i) != null ? int.parse(m.group(i)!) : 0;
    return DateTime(
      year2 ? 2000 + g(1) : g(1),
      g(2),
      g(3),
      m.groupCount >= 4 ? g(4) : 0,
      m.groupCount >= 5 ? g(5) : 0,
      m.groupCount >= 6 ? g(6) : 0,
    );
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
