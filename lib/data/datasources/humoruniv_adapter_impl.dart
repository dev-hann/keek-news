import 'package:flutter/foundation.dart';
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
    final dtos = await remoteDs.fetchMainPage();
    final items = dtos
        .map(
          (d) => FeedItemDto(
            community: CommunityId.humoruniv,
            id: d.id.toString(),
            title: d.title,
            url: d.url,
            recommendCount: d.recommendCount,
          ),
        )
        .toList();
    return FeedListResult(items: items);
  }

  @override
  Future<PostDetail> fetchDetail(String id) async {
    return remoteDs.fetchPostDetail(id);
  }

  @override
  Future<bool> healthCheck() async {
    try {
      await remoteDs.fetchMainPage();
      return true;
    } catch (e) {
      debugPrint('HumorunivAdapterImpl healthCheck failed: $e');
      return false;
    }
  }
}
