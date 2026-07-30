import 'package:flutter/foundation.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/feed_item_dto.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/service/community_adapter.dart';
import 'package:keek_news/service/humoruniv_remote_ds.dart';

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
    final url = '/board/read.html?table=pds&number=$id';
    return remoteDs.fetchPostDetail(url);
  }
}
