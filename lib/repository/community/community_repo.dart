import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/post_detail.dart';

abstract class CommunityRepo {
  CommunityId get communityId;

  Future<CommunityListResult> fetchLatest({String? pageToken});

  Future<LoadedPostDetail> fetchDetail(String id);
}

class CommunityListResult {
  const CommunityListResult({required this.items, this.pageToken});
  final List<FeedItem> items;
  final String? pageToken;
}
