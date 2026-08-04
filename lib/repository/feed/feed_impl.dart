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
    final persisted = ids == null || ids.isEmpty
        ? CommunityId.values.toSet()
        : ids.map((s) => CommunityId.values.byName(s)).toSet();
    // Hidden communities are never fetchable: drop them from the default set
    // (first run) and from any persisted selection so an older install that
    // had one enabled quietly stops fetching it without a crash.
    return persisted.difference(hiddenCommunityIds);
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
