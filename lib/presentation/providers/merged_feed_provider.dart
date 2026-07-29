import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happy_news/core/errors/failures.dart';
import 'package:happy_news/di/injection.dart';
import 'package:happy_news/domain/entities/community.dart';
import 'package:happy_news/domain/entities/feed_item.dart';
import 'package:happy_news/domain/entities/merged_feed.dart';
import 'package:happy_news/domain/entities/post_detail.dart';
import 'package:happy_news/domain/repositories/merged_feed_repository.dart';
import 'package:happy_news/domain/usecases/get_merged_feed.dart';

class MergedFeedState {
  const MergedFeedState({
    this.items = const [],
    this.cursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.hasMore = true,
    this.failedSources = const {},
  });

  final List<FeedItem> items;
  final MergedCursor? cursor;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final bool hasMore;
  final Set<CommunityId> failedSources;

  MergedFeedState copyWith({
    List<FeedItem>? items,
    MergedCursor? cursor,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool? hasMore,
    Set<CommunityId>? failedSources,
  }) {
    return MergedFeedState(
      items: items ?? this.items,
      cursor: cursor ?? this.cursor,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      hasMore: hasMore ?? this.hasMore,
      failedSources: failedSources ?? this.failedSources,
    );
  }
}

class MergedFeedNotifier extends StateNotifier<MergedFeedState> {
  MergedFeedNotifier() : super(const MergedFeedState(isLoading: true));

  Future<void> fetch() async {
    state = const MergedFeedState(isLoading: true);
    final result = await sl<GetMergedFeed>()(const MergedFeedParams());
    _applyResult(result);
  }

  Future<void> fetchNextPage() async {
    if (state.isLoadingMore || !state.hasMore || state.cursor == null) return;

    state = state.copyWith(isLoadingMore: true);
    final result = await sl<GetMergedFeed>()(
      MergedFeedParams(cursor: state.cursor),
    );

    result.fold((_) => state = state.copyWith(isLoadingMore: false), (page) {
      final existingIds = state.items
          .map((e) => '${e.community}:${e.id}')
          .toSet();
      final newItems = page.items
          .where((e) => !existingIds.contains('${e.community}:${e.id}'))
          .toList();
      state = MergedFeedState(
        items: [...state.items, ...newItems],
        cursor: page.next ?? state.cursor,
        hasMore: page.next != null,
        failedSources: page.failedSources,
      );
    });
  }

  void _applyResult(Either<Failure, MergedPage> result) {
    result.fold(
      (f) => state = MergedFeedState(error: f.message),
      (page) => state = MergedFeedState(
        items: page.items,
        cursor: page.next,
        hasMore: page.next != null,
        failedSources: page.failedSources,
      ),
    );
  }
}

final mergedFeedProvider =
    StateNotifierProvider.autoDispose<MergedFeedNotifier, MergedFeedState>((
      ref,
    ) {
      final notifier = MergedFeedNotifier();
      notifier.fetch();
      return notifier;
    });

final mergedDetailProvider = FutureProvider.autoDispose
    .family<Either<Failure, PostDetail>, ({CommunityId community, String id})>((
      ref,
      key,
    ) {
      return sl<MergedFeedRepository>().fetchDetail(
        community: key.community,
        id: key.id,
      );
    });
