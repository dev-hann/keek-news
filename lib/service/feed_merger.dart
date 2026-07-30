import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/merged_feed.dart';

MergedPage mergeFeedStreams({
  required Map<CommunityId, List<FeedItem>> streams,
  Map<CommunityId, String?> nextTokens = const {},
  DateTime? olderThan,
  int maxItems = 50,
}) {
  final all = <FeedItem>[];
  for (final items in streams.values) {
    all.addAll(items);
  }

  final filtered = olderThan == null
      ? all
      : all
            .where(
              (e) =>
                  e.publishedAt != null && e.publishedAt!.isBefore(olderThan),
            )
            .toList();

  final sorted = _sortByPublishedAtDescending(filtered);

  final limited = sorted.length > maxItems
      ? sorted.sublist(0, maxItems)
      : sorted;

  if (limited.isEmpty) {
    return MergedPage(items: limited);
  }

  final oldest = limited.last.publishedAt;
  if (oldest == null) {
    return MergedPage(items: limited);
  }

  return MergedPage(
    items: limited,
    next: MergedCursor(oldestSeen: oldest, perSourceTokens: Map.of(nextTokens)),
  );
}

List<FeedItem> _sortByPublishedAtDescending(List<FeedItem> items) {
  final nullTs = items.where((e) => e.publishedAt == null).toList();
  final hasTs = items.where((e) => e.publishedAt != null).toList();

  hasTs.sort((a, b) => b.publishedAt!.compareTo(a.publishedAt!));

  final result = <FeedItem>[];
  result.addAll(nullTs);

  var i = 0;
  var rotation = 0;
  while (i < hasTs.length) {
    var j = i;
    while (j < hasTs.length && hasTs[j].publishedAt == hasTs[i].publishedAt) {
      j++;
    }
    final group = hasTs.sublist(i, j);
    result.addAll(_interleaveBySource(group, rotation));
    rotation++;
    i = j;
  }

  return result;
}

List<FeedItem> _interleaveBySource(List<FeedItem> group, int rotation) {
  if (group.length <= 1) return group;

  final bySource = <CommunityId, List<FeedItem>>{};
  for (final item in group) {
    bySource.putIfAbsent(item.community, () => []).add(item);
  }

  final sources = bySource.keys.toList();
  final result = <FeedItem>[];
  var maxLen = 0;
  for (final items in bySource.values) {
    if (items.length > maxLen) maxLen = items.length;
  }

  for (var idx = 0; idx < maxLen; idx++) {
    for (var s = 0; s < sources.length; s++) {
      final sourceIdx = (s + rotation) % sources.length;
      final items = bySource[sources[sourceIdx]]!;
      if (idx < items.length) {
        result.add(items[idx]);
      }
    }
  }

  return result;
}
