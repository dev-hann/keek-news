import 'package:keek_news/model/community.dart';

abstract class FeedRepo {
  Set<CommunityId> getEnabledCommunities();

  /// Whether the user may flip the switch for [id]. Always `true` for a
  /// currently-disabled community (re-enabling is unrestricted). `false` only
  /// when [id] is the last remaining enabled community — keeps the feed from
  /// going empty.
  bool canDisable(CommunityId id);

  void toggleCommunity(CommunityId id);
}
