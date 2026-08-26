import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:keek_news/model/comment.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/content_scan_result.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/repository/community/html_community_repo.dart';
import 'package:keek_news/service/media_classifier.dart';

class HumorunivImpl extends HtmlCommunityRepo {
  const HumorunivImpl({required super.htmlClient});

  @override
  CommunityId get communityId => CommunityId.humoruniv;

  @override
  String listPath(String page) =>
      '/board/list.html?table=pds&pg=${int.tryParse(page) ?? 1}';

  @override
  String listRowSelector() => 'div.post_item a.post_link';

  @override
  int get listPageSize => 0;

  @override
  String? computeNextPageToken(
    dom.Document doc,
    String currentPage,
    List<FeedItem> items,
  ) {
    final page = int.tryParse(currentPage) ?? 1;
    final totalPage = _extractTotalPage(doc);
    return page < totalPage ? '${page + 1}' : null;
  }

  @override
  Future<LoadedPostDetail> fetchDetail(String id) async {
    final html = await htmlClient.get('/board/read.html?table=pds&number=$id');
    final doc = html_parser.parse(html);

    final contentEl = _findContentContainer(doc);
    final ContentScanResult scanResult;
    if (contentEl != null) {
      scanResult = htmlClient.scanContentFull(doc, contentEl);
    } else {
      scanResult = const ContentScanResult(blocks: [], imageUrls: []);
    }

    return LoadedPostDetail(
      id: int.tryParse(id) ?? 0,
      community: CommunityId.humoruniv,
      title: _extractTitle(doc),
      author: _extractAuthor(doc),
      date: _extractDate(doc),
      contentBlocks: scanResult.blocks,
      imageUrls: scanResult.imageUrls,
      recommendCount: _extractRecommendCount(doc),
      notRecommendCount: _extractNotRecommendCount(doc),
      viewCount: _extractViewCount(doc),
      commentCount: _extractCommentCount(doc),
      comments: _extractComments(doc),
    );
  }

  @override
  FeedItem? parseListRow(dom.Element anchor) {
    final number = anchor.attributes['data-number'] ?? '';
    final id = int.tryParse(number) ?? 0;
    if (id == 0) return null;

    final href = anchor.attributes['href'] ?? '';
    final url = _buildPostUrl(href);
    final title = htmlClient.textOf(anchor.querySelector('span.link_hover'));
    final author = htmlClient.textOf(anchor.querySelector('span.hu_nick_txt'));

    final blk = anchor.querySelector('span.blk');
    final recommendCount = htmlClient.statOf(blk, 'span.ok_num');
    final commentCount = htmlClient.statOf(blk, 'span.comment_num');
    final viewCount = _extractViewCountFromBlk(blk);

    final thumbnailUrl = _extractThumbnail(anchor);

    return FeedItem(
      community: CommunityId.humoruniv,
      id: id.toString(),
      title: title,
      url: url,
      author: author.isEmpty ? null : author,
      recommendCount: recommendCount,
      commentCount: commentCount,
      viewCount: viewCount,
      thumbnailUrl: thumbnailUrl.isEmpty ? null : thumbnailUrl,
    );
  }

  int _extractViewCountFromBlk(dom.Element? blk) {
    if (blk == null) return 0;
    final extras = blk.querySelectorAll('span.extra');
    for (final extra in extras) {
      final num = htmlClient.extractNumber(extra.text);
      if (num > 0) return num;
    }
    return 0;
  }

  String _extractThumbnail(dom.Element anchor) {
    final img = anchor.querySelector('td img.img');
    if (img == null) return '';
    final src = htmlClient.attrOf(img, 'src') ?? '';
    if (src.isEmpty || src.contains('no_image')) return '';
    final normalized = src.startsWith('//') ? 'https:$src' : src;
    return _fullSizeFromThumb(normalized);
  }

  String _fullSizeFromThumb(String url) {
    final match = RegExp(r'thumb\.php\?url=([^&]+)').firstMatch(url);
    if (match == null) return url;
    var original = Uri.decodeComponent(match.group(1)!);
    final sizeIdx = original.indexOf('?SIZE=');
    if (sizeIdx != -1) original = original.substring(0, sizeIdx);
    if (MediaClassifier.classify(original) == MediaType.video) {
      var thumbUrl = url;
      final outerSizeIdx = thumbUrl.indexOf('?SIZE=');
      if (outerSizeIdx != -1) thumbUrl = thumbUrl.substring(0, outerSizeIdx);
      return thumbUrl;
    }
    return original;
  }

  String _buildPostUrl(String href) {
    if (href.isEmpty) return '';
    final uri = Uri.tryParse(href);
    if (uri == null) return href;
    final table = uri.queryParameters['table'];
    final number = uri.queryParameters['number'];
    if (table != null && number != null) {
      return '/board/read.html?table=$table&number=$number';
    }
    return href;
  }

  int _extractTotalPage(dom.Document doc) {
    final links = doc.querySelectorAll('#pgnum a.def');
    if (links.isEmpty) return 0;
    var maxPage = 0;
    for (final a in links) {
      final href = a.attributes['href'] ?? '';
      final match = RegExp(r'pg=(\d+)').firstMatch(href);
      if (match != null) {
        final p = int.parse(match.group(1)!);
        if (p > maxPage) maxPage = p;
      }
    }
    return maxPage + 1;
  }

  String _extractTitle(dom.Document doc) {
    return htmlClient.textOfAny(doc.body, const [
      'title',
      'h1.read_title',
      '.read_title',
      '#read_title',
      '.view_title',
    ]);
  }

  String _extractAuthor(dom.Document doc) {
    return htmlClient.textOfAny(doc.body, const [
      '#read_profile_td .hu_nick_txt',
      '.hu_nick_txt',
      '.read_author',
      '.author_name',
      '.nick_name',
    ]);
  }

  DateTime _extractDate(dom.Document doc) {
    final descEl = doc.querySelector('#read_profile_desc');
    if (descEl == null) return DateTime.fromMillisecondsSinceEpoch(0);
    for (final el in descEl.querySelectorAll('.etc')) {
      final text = el.text.trim();
      if (text.startsWith('작성')) {
        final dateStr = text.replaceFirst('작성', '').trim();
        return DateTime.tryParse(dateStr) ??
            DateTime.fromMillisecondsSinceEpoch(0);
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  dom.Element? _findContentContainer(dom.Document doc) {
    return htmlClient.queryFirst(doc.body, const [
      '.body_editor',
      '.daum-wm-content',
      '.view_content',
      '.board-contents',
      '[itemprop="articleBody"]',
    ]);
  }

  int _extractRecommendCount(dom.Document doc) {
    return htmlClient.statOfAny(doc.body, const [
      '#ok_div',
      '.ok_div',
      '#ok_count',
      '.recommend_count',
      '[id^="ok_div"]',
    ]);
  }

  int _extractNotRecommendCount(dom.Document doc) {
    return htmlClient.statOfAny(doc.body, const [
      '#not_ok_span',
      '.not_ok_span',
      '#not_ok_count',
      '.not_recommend_count',
      '[id^="not_ok"]',
    ]);
  }

  int _extractViewCount(dom.Document doc) {
    final descEl = doc.querySelector('#read_profile_desc');
    if (descEl == null) return 0;
    for (final span in descEl.querySelectorAll('.etc')) {
      final img = span.querySelector('img[src*="ic_view"]');
      if (img == null) continue;
      return htmlClient.extractNumber(span.text);
    }
    return 0;
  }

  int _extractCommentCount(dom.Document doc) {
    final hit = htmlClient.queryFirst(doc.body, const [
      '#content_info h2 .comment_num',
      'h2 .comment_num',
      '.comment_num',
      '#comment_count',
      '[id^="comment_count"]',
    ]);
    if (hit == null) return 0;
    return htmlClient.extractBracketedInt(hit.text);
  }

  List<Comment> _extractComments(dom.Document doc) {
    final comments = <Comment>[];

    for (final item in doc.querySelectorAll('#comment_best_wrap .best_li')) {
      comments.add(_parseComment(item, isBest: true));
    }

    // humoruniv closes each parent <li> twice before its reply <li>s, so
    // the html5 parser detaches replies from their parent in the DOM.
    // Walk all comment <li>s in document order and attach each reply to
    // the nearest preceding non-reply comment instead.
    final replyElsByParent = <int, List<dom.Element>>{};
    for (final item in doc.querySelectorAll('li[id^="comment_li_"]')) {
      final isSub =
          item.classes.contains('sub_comm_bt') ||
          item.attributes['name'] == 'sub_comm_block';
      if (isSub) {
        if (comments.isNotEmpty) {
          replyElsByParent.putIfAbsent(comments.length - 1, () => []).add(item);
        }
        continue;
      }
      comments.add(_parseComment(item, isBest: false));
    }

    for (final entry in replyElsByParent.entries) {
      final parent = comments[entry.key];
      comments[entry.key] = Comment(
        id: parent.id,
        author: parent.author,
        content: parent.content,
        date: parent.date,
        recommendCount: parent.recommendCount,
        isBest: parent.isBest,
        mediaBlocks: parent.mediaBlocks,
        replies: [
          for (final el in entry.value) _parseComment(el, isBest: false),
        ],
      );
    }

    return comments;
  }

  Comment _parseComment(dom.Element item, {required bool isBest}) {
    final author = htmlClient.textOf(item.querySelector('.hu_nick_txt'));
    var content = '';
    final bodyEl = item.querySelector('.comment_body');
    if (bodyEl != null) {
      // 2026-08 redesign: humoruniv dropped `.comment_text` and wraps
      // bodies in `.comment_more`; the sibling `.comment_more_btn`
      // ("...전체보기") is pure UI and must never reach content. The
      // reply-count badge `.comment_num` ("[4]") is nested INSIDE
      // `.comment_more`, so both must be stripped before reading text.
      final textEl =
          bodyEl.querySelector('.comment_text') ??
          bodyEl.querySelector('.comment_more');
      if (textEl != null) {
        final clone = textEl.clone(true);
        clone
            .querySelectorAll('.comment_num, .comment_more_btn')
            .forEach((el) => el.remove());
        content = clone.text.trim();
      } else {
        final clone = bodyEl.clone(true);
        clone
            .querySelectorAll(
              '.recomm_btn, .btn_move, .comment_num, .comment_thumb_notice, '
              '.comment_img_div, .comment_crop_wrap, .comment_crop_href, '
              '.comment_crop_href_mp4, .comment_file, .comment_more_btn',
            )
            .forEach((el) => el.remove());
        content = clone.text.trim();
      }
    }

    final mediaBlocks = <ContentBlock>[];
    if (bodyEl != null) {
      mediaBlocks.addAll(htmlClient.scanContentCompact(bodyEl));
    }

    var date = DateTime.fromMillisecondsSinceEpoch(0);
    for (final el in item.querySelectorAll('.etc')) {
      final text = el.text.trim();
      final parsed = _parseCommentDate(text);
      if (parsed != null) {
        date = parsed;
        break;
      }
    }

    var recommendCount = 0;
    final okSpan = item.querySelector('.o');
    if (okSpan != null) {
      recommendCount = htmlClient.extractNumber(okSpan.text);
    }
    if (recommendCount == 0) {
      final rSpan = item.querySelector('.r');
      if (rSpan != null) {
        recommendCount = htmlClient.extractNumber(rSpan.text);
      }
    }

    final idNum = htmlClient.extractNumber(item.id);

    return Comment(
      id: idNum,
      author: author,
      content: content,
      date: date,
      recommendCount: recommendCount,
      isBest: isBest,
      mediaBlocks: mediaBlocks,
      replies: const [],
    );
  }

  /// Extracts `YYYY-MM-DD [HH:MM:SS]` from humoruniv's noisy `.etc` text.
  DateTime? _parseCommentDate(String text) {
    return parseDatePattern(
      text,
      RegExp(
        r'(\d{4})-(\d{1,2})-(\d{1,2})(?:[^\d]*?(\d{1,2}):(\d{2}):(\d{2}))?',
      ),
    );
  }
}
