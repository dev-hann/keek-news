import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/merged_feed.dart';
import 'package:keek_news/repository/community_repo.dart';

class MergedFeedParams {
  const MergedFeedParams({
    this.perSource = 20,
    this.cursor,
    this.enabled = const {},
  });

  final int perSource;
  final MergedCursor? cursor;
  final Set<CommunityId> enabled;
}

class GetMergedFeedUseCase {
  const GetMergedFeedUseCase({required this.repos});

  final Map<CommunityId, CommunityRepo> repos;

  Future<Either<Failure, MergedPage>> call(MergedFeedParams params) async {
    final active = params.enabled.isEmpty
        ? repos
        : Map.fromEntries(
            repos.entries.where((e) => params.enabled.contains(e.key)),
          );

    if (active.isEmpty) {
      return const Left(ServerFailure('No active community repos'));
    }

    final results = await Future.wait(
      active.entries.map((e) => _fetchOne(e.key, e.value, params.cursor)),
    );

    final streams = <CommunityId, List<FeedItem>>{};
    final nextTokens = <CommunityId, String?>{};
    final failed = <CommunityId>{};

    for (final r in results) {
      if (r.failed) {
        failed.add(r.id);
      } else {
        streams[r.id] = r.items;
        nextTokens[r.id] = r.nextToken;
      }
    }

    if (streams.isEmpty) {
      return const Left(ServerFailure('All community repos failed'));
    }

    return Right(
      _merge(
        streams: streams,
        nextTokens: nextTokens,
        olderThan: params.cursor?.oldestSeen,
        maxItems: params.perSource * active.length,
        failed: failed,
      ),
    );
  }

  Future<_FetchOutcome> _fetchOne(
    CommunityId id,
    CommunityRepo repo,
    MergedCursor? cursor,
  ) async {
    final token = cursor?.perSourceTokens[id];
    try {
      final result = await repo.fetchLatest(pageToken: token);
      return _FetchOutcome(id, result.items, result.pageToken);
    } catch (e) {
      debugPrint('GetMergedFeedUseCase: repo $id failed: $e');
      return _FetchOutcome.failed(id);
    }
  }

  MergedPage _merge({
    required Map<CommunityId, List<FeedItem>> streams,
    required Map<CommunityId, String?> nextTokens,
    required DateTime? olderThan,
    required int maxItems,
    required Set<CommunityId> failed,
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
      return MergedPage(items: limited, failedSources: failed);
    }

    final oldest = limited.last.publishedAt;
    if (oldest == null) {
      return MergedPage(items: limited, failedSources: failed);
    }

    return MergedPage(
      items: limited,
      next: MergedCursor(
        oldestSeen: oldest,
        perSourceTokens: Map.of(nextTokens),
      ),
      failedSources: failed,
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
}

class _FetchOutcome {
  _FetchOutcome(this.id, this.items, this.nextToken) : failed = false;
  _FetchOutcome.failed(this.id)
    : items = const [],
      nextToken = null,
      failed = true;
  final CommunityId id;
  final List<FeedItem> items;
  final String? nextToken;
  final bool failed;
}
