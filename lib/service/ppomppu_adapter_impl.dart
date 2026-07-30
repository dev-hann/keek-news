import 'package:flutter/foundation.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/service/community_adapter.dart';
import 'package:keek_news/service/html_client.dart';
import 'package:keek_news/service/parser/ppomppu_detail_parser.dart';
import 'package:keek_news/service/parser/ppomppu_list_parser.dart';

class PpomppuAdapterImpl implements CommunityAdapter {
  PpomppuAdapterImpl({required this.htmlClient});

  final HtmlClient htmlClient;

  @override
  CommunityId get communityId => CommunityId.ppomppu;

  @override
  Future<FeedListResult> fetchLatest({String? pageToken}) async {
    try {
      final page = pageToken ?? '1';
      final html = await htmlClient.get(
        '/zboard/zboard.php?id=humor&page=$page',
      );
      final items = PpomppuListParser.parse(html);
      final nextPage = (int.tryParse(page) ?? 0) + 1;
      return FeedListResult(
        items: items,
        pageToken: items.length >= 5 ? '$nextPage' : null,
      );
    } on ServerFailure {
      rethrow;
    } on NetworkFailure {
      rethrow;
    } catch (e) {
      debugPrint('PpomppuAdapterImpl fetchLatest error: $e');
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<PostDetail> fetchDetail(String id) async {
    try {
      final html = await htmlClient.get('/zboard/view.php?id=humor&no=$id');
      return PpomppuDetailParser.parse(html);
    } on ServerFailure {
      rethrow;
    } on NetworkFailure {
      rethrow;
    } catch (e) {
      debugPrint('PpomppuAdapterImpl fetchDetail error: $e');
      throw ServerFailure(e.toString());
    }
  }
}
