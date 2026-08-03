import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/merged_feed.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/repository/community/community_repo.dart';
import 'package:keek_news/repository/feed/feed_repo.dart';
import 'package:keek_news/use_case/base_use_case.dart';

class MergedFeedParams {
  const MergedFeedParams({this.perSource = 20, this.cursor});

  final int perSource;
  final MergedCursor? cursor;
}

class FeedUseCase extends BaseUseCase {
  const FeedUseCase({required this.repos, required this.feedRepo});

  final Map<CommunityId, CommunityRepo> repos;
  final FeedRepo feedRepo;

  Set<CommunityId> getEnabledCommunities() => feedRepo.getEnabledCommunities();

  bool canDisableCommunity(CommunityId id) => feedRepo.canDisable(id);

  void toggleCommunity(CommunityId id) => feedRepo.toggleCommunity(id);

  Future<Either<Failure, MergedPage>> getMergedFeed(
    MergedFeedParams params,
  ) async {
    final enabled = feedRepo.getEnabledCommunities();
    final active = Map.fromEntries(
      repos.entries.where((e) => enabled.contains(e.key)),
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
        maxItems: params.perSource * active.length,
        failed: failed,
      ),
    );
  }

  Future<PostDetail> getPostDetail({
    required CommunityId community,
    required String id,
  }) async {
    final repo = repos[community];
    final parsedId = int.tryParse(id) ?? 0;
    if (repo == null) {
      return ErrorPostDetail(
        id: parsedId,
        community: community,
        failure: ServerFailure('No repo for $community'),
      );
    }
    final result = await guard(() => repo.fetchDetail(id));
    return result.fold(
      (f) => ErrorPostDetail(id: parsedId, community: community, failure: f),
      (LoadedPostDetail d) => d.looksEmpty
          ? ErrorPostDetail(
              id: d.id,
              community: community,
              failure: const ParseFailure('본문 없음 — 차단 또는 구조 변경'),
            )
          : d,
    );
  }

  Future<_FetchOutcome> _fetchOne(
    CommunityId id,
    CommunityRepo repo,
    MergedCursor? cursor,
  ) async {
    final token = cursor?.perSourceTokens[id];
    final result = await guard(() => repo.fetchLatest(pageToken: token));
    return result.fold((f) {
      debugPrint('FeedUseCase: repo $id failed: $f');
      return _FetchOutcome.failed(id);
    }, (data) => _FetchOutcome(id, data.items, data.pageToken));
  }

  MergedPage _merge({
    required Map<CommunityId, List<FeedItem>> streams,
    required Map<CommunityId, String?> nextTokens,
    required int maxItems,
    required Set<CommunityId> failed,
  }) {
    final all = <FeedItem>[];
    for (final items in streams.values) {
      all.addAll(items);
    }

    final sorted = _sortByPublishedAtDescending(all);

    final limited = sorted.length > maxItems
        ? sorted.sublist(0, maxItems)
        : sorted;

    return MergedPage(
      items: limited,
      next: MergedCursor(perSourceTokens: Map.of(nextTokens)),
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
