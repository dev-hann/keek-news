import 'package:flutter/foundation.dart';
import 'package:humoruniv/core/errors/failures.dart';
import 'package:humoruniv/core/network/html_client.dart';
import 'package:humoruniv/data/datasources/community_adapter.dart';
import 'package:humoruniv/data/parsers/dogdrip_detail_parser.dart';
import 'package:humoruniv/data/parsers/dogdrip_list_parser.dart';
import 'package:humoruniv/domain/entities/community.dart';
import 'package:humoruniv/domain/entities/post_detail.dart';

class DogdripAdapterImpl implements CommunityAdapter {
  DogdripAdapterImpl({required this.htmlClient});

  final HtmlClient htmlClient;

  @override
  CommunityId get communityId => CommunityId.dogdrip;

  @override
  Future<FeedListResult> fetchLatest({String? pageToken}) async {
    try {
      final page = pageToken ?? '1';
      final html = await htmlClient.get(
        '/index.php?mid=dogdrip&page=$page',
      );
      final items = DogdripListParser.parse(html);
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
      debugPrint('DogdripAdapterImpl fetchLatest error: $e');
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<PostDetail> fetchDetail(String id) async {
    try {
      final html = await htmlClient.get('/$id');
      return DogdripDetailParser.parse(html);
    } on ServerFailure {
      rethrow;
    } on NetworkFailure {
      rethrow;
    } catch (e) {
      debugPrint('DogdripAdapterImpl fetchDetail error: $e');
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<bool> healthCheck() async {
    try {
      await htmlClient.get('/index.php?mid=dogdrip&page=1');
      return true;
    } catch (e) {
      debugPrint('DogdripAdapterImpl healthCheck failed: $e');
      return false;
    }
  }
}
