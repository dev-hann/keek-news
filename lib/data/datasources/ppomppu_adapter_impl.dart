import 'package:flutter/foundation.dart';
import 'package:happy_news/core/errors/failures.dart';
import 'package:happy_news/core/network/html_client.dart';
import 'package:happy_news/data/datasources/community_adapter.dart';
import 'package:happy_news/data/parsers/ppomppu_detail_parser.dart';
import 'package:happy_news/data/parsers/ppomppu_list_parser.dart';
import 'package:happy_news/domain/entities/community.dart';
import 'package:happy_news/domain/entities/post_detail.dart';

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
