import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/feed_item_dto.dart';
import 'package:keek_news/model/post_detail.dart';

abstract class CommunityAdapter {
  CommunityId get communityId;

  Future<FeedListResult> fetchLatest({String? pageToken});

  Future<PostDetail> fetchDetail(String id);
}

class FeedListResult {
  const FeedListResult({required this.items, this.pageToken});
  final List<FeedItemDto> items;
  final String? pageToken;
}
