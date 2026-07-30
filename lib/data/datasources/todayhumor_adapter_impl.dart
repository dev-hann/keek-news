import 'package:flutter/foundation.dart';
import 'package:happy_news/core/errors/failures.dart';
import 'package:happy_news/core/network/html_client.dart';
import 'package:happy_news/data/datasources/community_adapter.dart';
import 'package:happy_news/data/parsers/todayhumor_detail_parser.dart';
import 'package:happy_news/data/parsers/todayhumor_list_parser.dart';
import 'package:happy_news/domain/entities/community.dart';
import 'package:happy_news/domain/entities/post_detail.dart';

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
