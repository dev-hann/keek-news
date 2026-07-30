import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/merged_feed.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/repository/merged_feed/merged_feed_repo.dart';
import 'package:keek_news/service/community_adapter.dart';
import 'package:keek_news/service/feed_merger.dart';

class MergedFeedImpl implements MergedFeedRepo {
  MergedFeedImpl({
    required Map<CommunityId, CommunityAdapter> adapters,
    this.cacheTtl = const Duration(minutes: 2),
    this.detailCacheTtl = const Duration(minutes: 5),
    this.detailCacheMaxEntries = 50,
    DateTime Function()? now,
  }) : _adapters = adapters,
       _now = now ?? DateTime.now;

  final Map<CommunityId, CommunityAdapter> _adapters;
  final Duration cacheTtl;
  final Duration detailCacheTtl;
  final int detailCacheMaxEntries;
  final DateTime Function() _now;

  MergedPage? _cachedFirstPage;
  DateTime? _cachedAt;
  Set<CommunityId>? _cachedEnabled;

  final _DetailCache _detailCache = _DetailCache();

  @override
  Future<Either<Failure, MergedPage>> fetchMerged({
    required int perSource,
    MergedCursor? cursor,
    Set<CommunityId> enabled = const {},
  }) async {
    if (cursor == null && _isCacheValid(enabled)) {
      return Right(_cachedFirstPage!);
    }

    final active = enabled.isEmpty
        ? _adapters
        : Map.fromEntries(
            _adapters.entries.where((e) => enabled.contains(e.key)),
          );

    final results = await Future.wait(
      active.entries.map((entry) => _fetchOne(entry.key, entry.value, cursor)),
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
      return const Left(ServerFailure('All community adapters failed'));
    }

    final page = mergeFeedStreams(
      streams: streams,
      nextTokens: nextTokens,
      olderThan: cursor?.oldestSeen,
      maxItems: perSource * active.length,
    );

    final result = MergedPage(
      items: page.items,
      next: page.next,
      failedSources: failed,
    );

    if (cursor == null) {
      _cachedFirstPage = result;
      _cachedAt = _now();
      _cachedEnabled = enabled;
    }

    return Right(result);
  }

  bool _isCacheValid(Set<CommunityId> enabled) {
    if (_cachedFirstPage == null || _cachedAt == null) return false;
    final age = _now().difference(_cachedAt!);
    if (age > cacheTtl) return false;
    if (_cachedEnabled == null) return enabled.isEmpty;
    return _setEquals(_cachedEnabled!, enabled);
  }

  static bool _setEquals<T>(Set<T> a, Set<T> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  Future<Either<Failure, PostDetail>> fetchDetail({
    required CommunityId community,
    required String id,
  }) async {
    final key = (community: community, id: id);
    final cached = _detailCache.get(key, _now(), detailCacheTtl);
    if (cached != null) return Right(cached);

    final adapter = _adapters[community];
    if (adapter == null) {
      return Left(ServerFailure('No adapter for $community'));
    }
    try {
      final detail = await adapter.fetchDetail(id);
      _detailCache.put(key, detail, _now(), detailCacheMaxEntries);
      return Right(detail);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<_FetchOutcome> _fetchOne(
    CommunityId id,
    CommunityAdapter adapter,
    MergedCursor? cursor,
  ) async {
    final token = cursor?.perSourceTokens[id];
    try {
      final result = await adapter.fetchLatest(pageToken: token);
      final items = result.items.map((d) => d.toEntity()).toList();
      return _FetchOutcome(id, items, result.pageToken);
    } catch (e) {
      debugPrint('MergedFeedImpl: adapter $id failed: $e');
      return _FetchOutcome.failed(id);
    }
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

typedef DetailCacheKey = ({CommunityId community, String id});

class _DetailCache {
  final Map<DetailCacheKey, DateTime> _cachedAt = {};

  PostDetail? get(DetailCacheKey key, DateTime now, Duration ttl) {
    final cached = _store[key];
    final at = _cachedAt[key];
    if (cached == null || at == null) return null;
    if (now.difference(at) > ttl) {
      _store.remove(key);
      _cachedAt.remove(key);
      return null;
    }
    _store.remove(key);
    _store[key] = cached;
    _cachedAt.remove(key);
    _cachedAt[key] = now;
    return cached;
  }

  void put(
    DetailCacheKey key,
    PostDetail detail,
    DateTime now,
    int maxEntries,
  ) {
    _store[key] = detail;
    _cachedAt[key] = now;
    while (_store.length > maxEntries) {
      final oldest = _store.keys.first;
      _store.remove(oldest);
      _cachedAt.remove(oldest);
    }
  }

  final Map<DetailCacheKey, PostDetail> _store = {};
}
