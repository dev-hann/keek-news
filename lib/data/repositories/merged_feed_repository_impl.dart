import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:happy_news/core/errors/failures.dart';
import 'package:happy_news/data/datasources/community_adapter.dart';
import 'package:happy_news/domain/entities/community.dart';
import 'package:happy_news/domain/entities/feed_item.dart';
import 'package:happy_news/domain/entities/merged_feed.dart';
import 'package:happy_news/domain/entities/post_detail.dart';
import 'package:happy_news/domain/repositories/merged_feed_repository.dart';
import 'package:happy_news/domain/services/feed_merger.dart';

class MergedFeedRepositoryImpl implements MergedFeedRepository {
  MergedFeedRepositoryImpl({
    required Map<CommunityId, CommunityAdapter> adapters,
    this.cacheTtl = const Duration(minutes: 2),
  }) : _adapters = adapters;

  final Map<CommunityId, CommunityAdapter> _adapters;
  final Duration cacheTtl;

  MergedPage? _cachedFirstPage;
  DateTime? _cachedAt;
  Set<CommunityId>? _cachedEnabled;

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
      return Left(ServerFailure('All community adapters failed'));
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
      _cachedAt = DateTime.now();
      _cachedEnabled = enabled;
    }

    return Right(result);
  }

  bool _isCacheValid(Set<CommunityId> enabled) {
    if (_cachedFirstPage == null || _cachedAt == null) return false;
    final age = DateTime.now().difference(_cachedAt!);
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
    final adapter = _adapters[community];
    if (adapter == null) {
      return Left(ServerFailure('No adapter for $community'));
    }
    try {
      final detail = await adapter.fetchDetail(id);
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
      debugPrint('MergedFeedRepositoryImpl: adapter $id failed: $e');
      return _FetchOutcome.failed(id);
    }
  }
}

class _FetchOutcome {
  final CommunityId id;
  final List<FeedItem> items;
  final String? nextToken;
  final bool failed;

  _FetchOutcome(this.id, this.items, this.nextToken) : failed = false;
  _FetchOutcome.failed(this.id)
    : items = const [],
      nextToken = null,
      failed = true;
}
