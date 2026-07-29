import 'package:happy_news/data/models/feed_item_dto.dart';
import 'package:happy_news/domain/entities/community.dart';
import 'package:happy_news/domain/entities/post_detail.dart';

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
