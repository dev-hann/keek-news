import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:humoruniv/core/errors/failures.dart';
import 'package:humoruniv/data/datasources/community_adapter.dart';
import 'package:humoruniv/domain/entities/community.dart';
import 'package:humoruniv/domain/entities/feed_item.dart';
import 'package:humoruniv/domain/entities/merged_feed.dart';
import 'package:humoruniv/domain/repositories/merged_feed_repository.dart';
import 'package:humoruniv/domain/services/feed_merger.dart';

class MergedFeedRepositoryImpl implements MergedFeedRepository {
  MergedFeedRepositoryImpl({
    required Map<CommunityId, CommunityAdapter> adapters,
  }) : _adapters = adapters;

  final Map<CommunityId, CommunityAdapter> _adapters;

  @override
  Future<Either<Failure, MergedPage>> fetchMerged({
    required int perSource,
    MergedCursor? cursor,
    Set<CommunityId> enabled = const {},
  }) async {
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

    return Right(MergedPage(
      items: page.items,
      next: page.next,
      failedSources: failed,
    ));
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
