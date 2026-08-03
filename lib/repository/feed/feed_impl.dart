import 'package:keek_news/model/community.dart';
import 'package:keek_news/repository/feed/feed_repo.dart';
import 'package:keek_news/service/local_storage_service.dart';

class FeedImpl implements FeedRepo {
  FeedImpl(this._storage);

  final LocalStorageService _storage;

  static const _enabledKey = 'enabled_communities';

  @override
  Set<CommunityId> getEnabledCommunities() {
    final ids = _storage.getStringList(_enabledKey);
    if (ids == null || ids.isEmpty) {
      return CommunityId.values.toSet();
    }
    return ids.map((s) => CommunityId.values.byName(s)).toSet();
  }

  @override
  bool canDisable(CommunityId id) {
    final enabled = getEnabledCommunities();
    // A community that is currently off can always be turned back on; only the
    // last enabled community is locked to prevent an empty feed.
    return !enabled.contains(id) || enabled.length > 1;
  }

  @override
  void toggleCommunity(CommunityId id) {
    final current = getEnabledCommunities();
    final next = Set<CommunityId>.of(current);
    if (next.contains(id)) {
      if (next.length <= 1) return;
      next.remove(id);
    } else {
      next.add(id);
    }
    _storage.setStringList(_enabledKey, next.map((e) => e.name).toList());
  }
}
