import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:keek_news/model/comment.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/content_scan_result.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/repository/community_repo.dart';
import 'package:keek_news/repository/humoruniv/humoruniv_repo.dart';
import 'package:keek_news/service/html_service.dart';
import 'package:keek_news/utils/media_classifier.dart';

class HumorunivImpl implements HumorunivRepo {
  const HumorunivImpl({required this.htmlClient});

  final HtmlService htmlClient;

  @override
  CommunityId get communityId => CommunityId.humoruniv;

  @override
  Future<CommunityListResult> fetchLatest({String? pageToken}) async {
    try {
      final page = int.tryParse(pageToken ?? '1') ?? 1;
      final html = await htmlClient.get('/board/list.html?table=pds&pg=$page');
      final doc = html_parser.parse(html);

      final items = doc
          .querySelectorAll('div.post_item a.post_link')
          .map(_parseListRow)
          .whereType<FeedItem>()
          .toList();

      final totalPage = _extractTotalPage(doc);
      final nextPage = page < totalPage ? '${page + 1}' : null;
      return CommunityListResult(items: items, pageToken: nextPage);
    } on ServerFailure {
      rethrow;
    } on NetworkFailure {
      rethrow;
    } catch (e) {
      debugPrint('HumorunivImpl fetchLatest error: $e');
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<PostDetail> fetchDetail(String id) async {
    try {
      final html = await htmlClient.get(
        '/board/read.html?table=pds&number=$id',
      );
      final doc = html_parser.parse(html);

      final contentEl = _findContentContainer(doc);
      final ContentScanResult scanResult;
      if (contentEl != null) {
        scanResult = htmlClient.scanContentFull(doc, contentEl);
      } else {
        scanResult = const ContentScanResult(
          blocks: const [],
          imageUrls: const [],
        );
      }

      return PostDetail(
        id: int.tryParse(id) ?? 0,
        title: _extractTitle(doc),
        author: _extractAuthor(doc),
        date: _extractDate(doc),
        contentHtml: _extractContentHtml(doc),
        contentBlocks: scanResult.blocks,
        imageUrls: scanResult.imageUrls,
        recommendCount: _extractRecommendCount(doc),
        notRecommendCount: _extractNotRecommendCount(doc),
        viewCount: _extractViewCount(doc),
        commentCount: _extractCommentCount(doc),
        comments: _extractComments(doc),
        community: CommunityId.humoruniv,
      );
    } on ServerFailure {
      rethrow;
    } on NetworkFailure {
      rethrow;
    } catch (e) {
      debugPrint('HumorunivImpl fetchDetail error: $e');
      throw ServerFailure(e.toString());
    }
  }

  FeedItem? _parseListRow(dom.Element anchor) {
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
    return htmlClient.textOf(doc.querySelector('title'));
  }

  String _extractAuthor(dom.Document doc) {
    return htmlClient.textOf(
      doc.querySelector('#read_profile_td .hu_nick_txt'),
    );
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

  String _extractContentHtml(dom.Document doc) {
    final bodyEditor = doc.querySelector('.body_editor');
    if (bodyEditor != null) return bodyEditor.innerHtml;
    final daumContent = doc.querySelector('.daum-wm-content');
    return daumContent?.innerHtml ?? '';
  }

  dom.Element? _findContentContainer(dom.Document doc) {
    final bodyEditor = doc.querySelector('.body_editor');
    if (bodyEditor != null) return bodyEditor;
    return doc.querySelector('.daum-wm-content');
  }

  int _extractRecommendCount(dom.Document doc) {
    return htmlClient.statOf(doc.body, '#ok_div');
  }

  int _extractNotRecommendCount(dom.Document doc) {
    return htmlClient.statOf(doc.body, '#not_ok_span');
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
    var h2s = doc.querySelectorAll('#content_info h2 .comment_num');
    if (h2s.isEmpty) {
      h2s = doc.querySelectorAll('h2 .comment_num');
    }
    if (h2s.isEmpty) return 0;
    final text = h2s.first.text.trim();
    final match = RegExp(r'\[(\d+)\]').firstMatch(text);
    return match != null ? int.parse(match.group(1)!) : 0;
  }

  List<Comment> _extractComments(dom.Document doc) {
    final comments = <Comment>[];

    for (final item in doc.querySelectorAll('#comment_best_wrap .best_li')) {
      comments.add(_parseComment(item, isBest: true));
    }

    for (final item in doc.querySelectorAll('li[id^="comment_li_"]')) {
      final isSub =
          item.classes.contains('sub_comm_bt') ||
          item.attributes['name'] == 'sub_comm_block';
      if (isSub) continue;

      final comment = _parseComment(item, isBest: false);
      final replies = <Comment>[];
      for (final sub in item.querySelectorAll('li.sub_comm_bt')) {
        replies.add(_parseComment(sub, isBest: false));
      }

      comments.add(
        Comment(
          id: comment.id,
          author: comment.author,
          content: comment.content,
          date: comment.date,
          recommendCount: comment.recommendCount,
          isBest: comment.isBest,
          mediaBlocks: comment.mediaBlocks,
          replies: replies,
        ),
      );
    }

    return comments;
  }

  Comment _parseComment(dom.Element item, {required bool isBest}) {
    final author = htmlClient.textOf(item.querySelector('.hu_nick_txt'));

    final bodyEl = item.querySelector('.comment_body');
    var content = '';
    if (bodyEl != null) {
      final textEl = bodyEl.querySelector('.comment_text');
      if (textEl != null) {
        content = textEl.text.trim();
      } else {
        final clone = bodyEl.clone(true);
        clone
            .querySelectorAll(
              '.recomm_btn, .btn_move, .comment_num, .comment_thumb_notice, '
              '.comment_img_div, .comment_crop_wrap, .comment_crop_href, '
              '.comment_crop_href_mp4',
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
      final parsed = DateTime.tryParse(text);
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
}
