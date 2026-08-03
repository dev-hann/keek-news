import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:keek_news/model/comment.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/repository/community/html_community_repo.dart';
import 'package:keek_news/service/html_service.dart';

class FmkoreaImpl extends HtmlCommunityRepo {
  FmkoreaImpl({required super.htmlClient});

  @override
  CommunityId get communityId => CommunityId.fmkorea;

  @override
  String listPath(String page) => '/index.php?mid=humor&page=$page';

  @override
  String listRowSelector() => '.bd_lst tbody tr';

  @override
  int get listPageSize => 30;

  @override
  FeedItem? parseListRow(dom.Element row) {
    final titleCell = row.querySelector('td.title');
    if (titleCell == null) return null;

    final titleLink = titleCell.querySelectorAll('a').where((a) {
      final href = a.attributes['href'] ?? '';
      final cls = a.className;
      return href.isNotEmpty &&
          !cls.contains('replyNum') &&
          !cls.contains('category');
    }).firstOrNull;
    if (titleLink == null) return null;

    final href = titleLink.attributes['href'] ?? '';
    final idMatch = RegExp(r'^/(\d+)').firstMatch(href);
    if (idMatch == null) return null;
    final id = idMatch.group(1)!;

    final title = titleLink.text.trim();
    if (title.isEmpty) return null;

    final author = htmlClient.textOf(row.querySelector('td.author'));

    final timeText = htmlClient.textOf(row.querySelector('td.time'));
    final publishedAt = _parseTime(timeText);

    final commentLink = titleCell.querySelector('a.replyNum');
    final commentCount = htmlClient.extractNumber(commentLink?.text ?? '0');

    final viewCount = htmlClient.statOf(row, 'td.m_no:not(.m_no_voted)');

    final thumbImg = row.querySelector('img');
    final thumbSrc = htmlClient.attrOf(thumbImg, 'src');
    final thumbnailUrl = (thumbSrc != null && thumbSrc.isNotEmpty)
        ? thumbSrc
        : null;

    return FeedItem(
      community: CommunityId.fmkorea,
      id: id,
      title: title,
      url: href,
      author: author.isEmpty ? null : author,
      publishedAt: publishedAt,
      commentCount: commentCount,
      viewCount: viewCount,
      thumbnailUrl: thumbnailUrl,
    );
  }

  @override
  Future<LoadedPostDetail> fetchDetail(String id) async {
    final html = await htmlClient.get('/$id');
    final doc = html_parser.parse(html);
    final contentEl = doc.querySelector('.rd_body');

    return LoadedPostDetail(
      id: int.tryParse(id) ?? 0,
      title: _extractTitle(doc),
      author: _extractAuthor(doc),
      date: _extractDate(doc) ?? DateTime.now(),
      contentHtml: contentEl?.innerHtml ?? '',
      contentBlocks: _buildBlocks(contentEl),
      imageUrls: htmlClient.collectImageUrls(contentEl, community: communityId),
      recommendCount: _extractRecommendCount(doc),
      notRecommendCount: 0,
      viewCount: _extractViewCount(doc),
      commentCount: _extractCommentCount(doc),
      comments: _extractComments(doc),
      community: CommunityId.fmkorea,
    );
  }

  DateTime? _parseTime(String text) {
    final trimmed = text.trim();
    final now = DateTime.now();

    final hmMatch = RegExp(r'(\d{2}):(\d{2})').firstMatch(trimmed);
    if (hmMatch != null) {
      return DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(hmMatch.group(1)!),
        int.parse(hmMatch.group(2)!),
      );
    }

    final dateMatch = RegExp(r'(\d{2})\.(\d{2})').firstMatch(trimmed);
    if (dateMatch != null) {
      return DateTime(
        now.year,
        int.parse(dateMatch.group(1)!),
        int.parse(dateMatch.group(2)!),
      );
    }

    return null;
  }

  String _extractTitle(dom.Document doc) {
    final titleTag = doc.querySelector('title');
    if (titleTag != null) {
      final full = titleTag.text.trim();
      final dashIdx = full.lastIndexOf(' - ');
      if (dashIdx > 0) return full.substring(0, dashIdx).trim();
      return full;
    }
    return '';
  }

  String _extractAuthor(dom.Document doc) {
    final authorEl = doc.querySelector(
      '.rd_nb .nick_name, .author .member, .rd_author,'
      ' .rd_hd .btm_area .member_plate',
    );
    return htmlClient.textOf(authorEl);
  }

  DateTime? _extractDate(dom.Document doc) {
    final timeEl = doc.querySelector('.rd_nb .date, .rd_time, .time');
    final text = htmlClient.textOf(timeEl);
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

  int _extractRecommendCount(dom.Document doc) {
    final votedEl = doc.querySelector(
      '.list_comment .voted, .rd_voted, #voted_count',
    );
    return htmlClient.extractNumber(votedEl?.text ?? '0');
  }

  int _extractViewCount(dom.Document doc) {
    final readEl = doc.querySelector('.rd_nb .read, .m_no, .read_count');
    return htmlClient.extractNumber(readEl?.text ?? '0');
  }

  int _extractCommentCount(dom.Document doc) {
    final cmtEl = doc.querySelector('.list_comment .replyNum, #cmt_count');
    return htmlClient.extractNumber(cmtEl?.text ?? '0');
  }

  List<ContentBlock> _buildBlocks(dom.Element? content) {
    if (content == null) return const [];
    return htmlClient.buildContentBlocks(
      content.children,
      const ContentBlockConfig(community: CommunityId.fmkorea),
      fallbackText: content.text,
    );
  }

  List<Comment> _extractComments(dom.Document doc) {
    final items = doc.querySelectorAll('.fdb_itm, .cmt_item, .comment_item');
    return items.map(_parseComment).whereType<Comment>().toList();
  }

  Comment? _parseComment(dom.Element item) {
    final author = htmlClient.textOf(
      item.querySelector('.nick_name, .author, .member'),
    );
    final contentEl = item.querySelector(
      '.xe_content, .rd_cmt_text, .comment_text',
    );
    final content = htmlClient.textOf(contentEl);

    var recommendCount = 0;
    final votedEl = item.querySelector('.voted, .reply_voted');
    if (votedEl != null) {
      recommendCount = htmlClient.extractNumber(votedEl.text);
    }

    final idStr = item.id.replaceAll(RegExp(r'\D'), '');
    final id = int.tryParse(idStr) ?? 0;

    if (content.isEmpty && author.isEmpty) return null;

    return Comment(
      id: id,
      author: author,
      content: content,
      date: DateTime.now(),
      recommendCount: recommendCount,
      isBest: false,
      replies: const [],
    );
  }
}
