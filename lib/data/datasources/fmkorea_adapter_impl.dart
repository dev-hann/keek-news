import 'package:flutter/foundation.dart';
import 'package:humoruniv/core/errors/failures.dart';
import 'package:humoruniv/core/network/html_client.dart';
import 'package:humoruniv/data/datasources/community_adapter.dart';
import 'package:humoruniv/data/parsers/fmkorea_detail_parser.dart';
import 'package:humoruniv/data/parsers/fmkorea_list_parser.dart';
import 'package:humoruniv/domain/entities/community.dart';
import 'package:humoruniv/domain/entities/post_detail.dart';

class FmkoreaAdapterImpl implements CommunityAdapter {
  FmkoreaAdapterImpl({required this.htmlClient});

  final HtmlClient htmlClient;

  @override
  CommunityId get communityId => CommunityId.fmkorea;

  @override
  Future<FeedListResult> fetchLatest({String? pageToken}) async {
    try {
      final page = pageToken ?? '1';
      final html = await htmlClient.get('/humorbest&page=$page');
      final items = FmkoreaListParser.parse(html);
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
      debugPrint('FmkoreaAdapterImpl fetchLatest error: $e');
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<PostDetail> fetchDetail(String id) async {
    try {
      final html = await htmlClient.get('/$id');
      return FmkoreaDetailParser.parse(html);
    } on ServerFailure {
      rethrow;
    } on NetworkFailure {
      rethrow;
    } catch (e) {
      debugPrint('FmkoreaAdapterImpl fetchDetail error: $e');
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<bool> healthCheck() async {
    try {
      await htmlClient.get('/humorbest&page=1');
      return true;
    } catch (e) {
      debugPrint('FmkoreaAdapterImpl healthCheck failed: $e');
      return false;
    }
  }
}
