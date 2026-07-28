import 'package:humoruniv/data/models/feed_item_dto.dart';
import 'package:humoruniv/data/models/post_detail_dto.dart';
import 'package:humoruniv/domain/entities/community.dart';

abstract class CommunityAdapter {
  CommunityId get communityId;

  Future<FeedListResult> fetchLatest({String? pageToken});

  Future<PostDetailDto> fetchDetail(String id);

  Future<bool> healthCheck();
}

class FeedListResult {
  const FeedListResult({required this.items, this.pageToken});
  final List<FeedItemDto> items;
  final String? pageToken;
}
