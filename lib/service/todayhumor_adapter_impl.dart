import 'package:flutter/foundation.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/service/community_adapter.dart';
import 'package:keek_news/service/html_client.dart';
import 'package:keek_news/service/parser/todayhumor_detail_parser.dart';
import 'package:keek_news/service/parser/todayhumor_list_parser.dart';

class TodayhumorAdapterImpl implements CommunityAdapter {
  TodayhumorAdapterImpl({required this.htmlClient});

  final HtmlClient htmlClient;

  @override
  CommunityId get communityId => CommunityId.todayhumor;

  @override
  Future<FeedListResult> fetchLatest({String? pageToken}) async {
    try {
      final page = pageToken ?? '1';
      final html = await htmlClient.get(
        '/board/list.php?table=humorbest&page=$page',
      );
      final items = TodayhumorListParser.parse(html);
      final nextPage = (int.tryParse(page) ?? 0) + 1;
      return FeedListResult(
        items: items,
        pageToken: items.length >= 10 ? '$nextPage' : null,
      );
    } on ServerFailure {
      rethrow;
    } on NetworkFailure {
      rethrow;
    } catch (e) {
      debugPrint('TodayhumorAdapterImpl fetchLatest error: $e');
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<PostDetail> fetchDetail(String id) async {
    try {
      final html = await htmlClient.get(
        '/board/view.php?table=humorbest&no=$id',
      );
      return TodayhumorDetailParser.parse(html);
    } on ServerFailure {
      rethrow;
    } on NetworkFailure {
      rethrow;
    } catch (e) {
      debugPrint('TodayhumorAdapterImpl fetchDetail error: $e');
      throw ServerFailure(e.toString());
    }
  }
}
