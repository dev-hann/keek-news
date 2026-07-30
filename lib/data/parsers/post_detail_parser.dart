import 'package:happy_news/data/parsers/content_scanner.dart';
import 'package:happy_news/domain/entities/comment.dart';
import 'package:happy_news/domain/entities/content_block.dart';
import 'package:happy_news/domain/entities/post_detail.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

class PostDetailParser {
  static PostDetail parse(String htmlString) {
    if (htmlString.isEmpty) {
      return _emptyDetail();
    }

    final doc = html_parser.parse(htmlString);

    final title = _extractTitle(doc);
    final author = _extractAuthor(doc);
    final date = _extractDate(doc);
    final contentHtml = _extractContentHtml(doc);
    final contentEl = _findContentContainer(doc);

    final ContentScanResult scanResult;
    if (contentEl != null) {
      scanResult = ContentScanner.scanFull(doc, contentEl);
    } else {
      scanResult = const ContentScanResult(blocks: [], imageUrls: []);
    }

    final recommendCount = _extractRecommendCount(doc);
    final notRecommendCount = _extractNotRecommendCount(doc);
    final viewCount = _extractViewCount(doc);
    final commentCount = _extractCommentCount(doc);
    final comments = _extractComments(doc);

    return PostDetail(
      id: 0,
      title: title,
      author: author,
      date: date,
      contentHtml: contentHtml,
      contentBlocks: scanResult.blocks,
      imageUrls: scanResult.imageUrls,
      recommendCount: recommendCount,
      notRecommendCount: notRecommendCount,
      viewCount: viewCount,
      commentCount: commentCount,
      comments: comments,
    );
  }

  static PostDetail _emptyDetail() {
    return PostDetail(
      id: 0,
      title: '',
      author: '',
      date: DateTime(1970),
      contentHtml: '',
      contentBlocks: const [],
      imageUrls: const [],
      recommendCount: 0,
      notRecommendCount: 0,
      viewCount: 0,
      commentCount: 0,
      comments: const [],
    );
  }

  static String _extractTitle(dom.Document doc) {
    final titleEl = doc.querySelector('title');
    if (titleEl == null) return '';
    return titleEl.text.trim();
  }

  static String _extractAuthor(dom.Document doc) {
    final nickEl = doc.querySelector('#read_profile_td .hu_nick_txt');
    if (nickEl == null) return '';
    return nickEl.text.trim();
  }

  static DateTime _extractDate(dom.Document doc) {
    final descEl = doc.querySelector('#read_profile_desc');
    if (descEl == null) return DateTime(1970);
    final etcEls = descEl.querySelectorAll('.etc');
    for (final el in etcEls) {
      final text = el.text.trim();
      if (text.startsWith('작성')) {
        final dateStr = text.replaceFirst('작성', '').trim();
        return DateTime.tryParse(dateStr) ?? DateTime(1970);
      }
    }
    return DateTime(1970);
  }

  static String _extractContentHtml(dom.Document doc) {
    final bodyEditor = doc.querySelector('.body_editor');
    if (bodyEditor != null) return bodyEditor.innerHtml;
    final daumContent = doc.querySelector('.daum-wm-content');
    if (daumContent != null) return daumContent.innerHtml;
    return '';
  }

  static dom.Element? _findContentContainer(dom.Document doc) {
    final bodyEditor = doc.querySelector('.body_editor');
    if (bodyEditor != null) return bodyEditor;
    return doc.querySelector('.daum-wm-content');
  }

  static int _extractRecommendCount(dom.Document doc) {
    final okDiv = doc.querySelector('#ok_div');
    if (okDiv == null) return 0;
    return int.tryParse(okDiv.text.trim()) ?? 0;
  }

  static int _extractNotRecommendCount(dom.Document doc) {
    final notOkSpan = doc.querySelector('#not_ok_span');
    if (notOkSpan == null) return 0;
    return int.tryParse(notOkSpan.text.trim()) ?? 0;
  }

  static int _extractViewCount(dom.Document doc) {
    final descEl = doc.querySelector('#read_profile_desc');
    if (descEl == null) return 0;

    for (final span in descEl.querySelectorAll('.etc')) {
      final img = span.querySelector('img[src*="ic_view"]');
      if (img == null) continue;
      final match = RegExp(r'(\d[\d,]*)').firstMatch(span.text);
      if (match == null) continue;
      return int.tryParse(match.group(1)!.replaceAll(',', '')) ?? 0;
    }

    return 0;
  }

  static int _extractCommentCount(dom.Document doc) {
    var h2s = doc.querySelectorAll('#content_info h2 .comment_num');
    if (h2s.isEmpty) {
      h2s = doc.querySelectorAll('h2 .comment_num');
    }
    if (h2s.isEmpty) return 0;
    final text = h2s.first.text.trim();
    final match = RegExp(r'\[(\d+)\]').firstMatch(text);
    return match != null ? int.parse(match.group(1)!) : 0;
  }

  static List<Comment> _extractComments(dom.Document doc) {
    final comments = <Comment>[];

    final bestItems = doc.querySelectorAll('#comment_best_wrap .best_li');
    for (final item in bestItems) {
      comments.add(_parseCommentItem(item, isBest: true));
    }

    final regularItems = doc.querySelectorAll('li[id^="comment_li_"]');
    for (final item in regularItems) {
      final isSub =
          item.classes.contains('sub_comm_bt') ||
          item.attributes['name'] == 'sub_comm_block';
      if (isSub) continue;

      final comment = _parseCommentItem(item, isBest: false);

      final subItems = item.querySelectorAll('li.sub_comm_bt');
      final replies = <Comment>[];
      for (final sub in subItems) {
        replies.add(_parseCommentItem(sub, isBest: false));
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

  static Comment _parseCommentItem(dom.Element item, {required bool isBest}) {
    final nickEl = item.querySelector('.hu_nick_txt');
    final author = nickEl?.text.trim() ?? '';

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
              '.recomm_btn, .btn_move, .comment_num, .comment_thumb_notice, .comment_img_div, .comment_crop_wrap, .comment_crop_href, .comment_crop_href_mp4',
            )
            .forEach((el) => el.remove());
        content = clone.text.trim();
      }
    }

    final mediaBlocks = <ContentBlock>[];
    if (bodyEl != null) {
      mediaBlocks.addAll(ContentScanner.scanCompact(bodyEl));
    }

    final etcEls = item.querySelectorAll('.etc');
    var date = DateTime(1970);
    for (final el in etcEls) {
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
      recommendCount = int.tryParse(okSpan.text.trim()) ?? 0;
    }
    final rSpan = item.querySelector('.r');
    if (rSpan != null && recommendCount == 0) {
      recommendCount = int.tryParse(rSpan.text.trim()) ?? 0;
    }

    final idAttr = item.id;
    final idNum = int.tryParse(idAttr.replaceAll(RegExp('[^0-9]'), '')) ?? 0;

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
