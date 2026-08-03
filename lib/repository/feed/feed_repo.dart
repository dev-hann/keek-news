import 'package:keek_news/model/community.dart';

abstract class FeedRepo {
  Set<CommunityId> getEnabledCommunities();

  bool canDisable(CommunityId id);

  void toggleCommunity(CommunityId id);
}
