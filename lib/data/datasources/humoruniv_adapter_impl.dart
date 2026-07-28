import 'package:flutter/foundation.dart';
import 'package:humoruniv/core/errors/failures.dart';
import 'package:humoruniv/data/datasources/community_adapter.dart';
import 'package:humoruniv/data/datasources/humoruniv_remote_ds.dart';
import 'package:humoruniv/data/models/feed_item_dto.dart';
import 'package:humoruniv/domain/entities/community.dart';
import 'package:humoruniv/domain/entities/post_detail.dart';

class HumorunivAdapterImpl implements CommunityAdapter {
  const HumorunivAdapterImpl({required this.remoteDs});

  final HumorunivRemoteDs remoteDs;

  @override
  CommunityId get communityId => CommunityId.humoruniv;

  @override
  Future<FeedListResult> fetchLatest({String? pageToken}) async {
    try {
      final page = int.tryParse(pageToken ?? '1') ?? 1;
      final result = await remoteDs.fetchBoardList('pds', page, '');
      final items = result.posts
          .map(
            (d) => FeedItemDto(
              community: CommunityId.humoruniv,
              id: d.id.toString(),
              title: d.title,
              url: d.url,
              author: d.author,
              recommendCount: d.recommendCount,
              commentCount: d.commentCount,
              viewCount: d.viewCount,
              thumbnailUrl: d.thumbnailUrl.isNotEmpty ? d.thumbnailUrl : null,
            ),
          )
          .toList();
      final nextPage = page < result.totalPage ? '${page + 1}' : null;
      return FeedListResult(items: items, pageToken: nextPage);
    } on ServerFailure {
      rethrow;
    } on NetworkFailure {
      rethrow;
    } catch (e) {
      debugPrint('HumorunivAdapterImpl fetchLatest error: $e');
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<PostDetail> fetchDetail(String id) async {
    return remoteDs.fetchPostDetail(id);
  }

  @override
  Future<bool> healthCheck() async {
    try {
      await remoteDs.fetchBoardList('pds', 1, '');
      return true;
    } catch (e) {
      debugPrint('HumorunivAdapterImpl healthCheck failed: $e');
      return false;
    }
  }
}
