import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/merged_feed.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/service/service_locator.dart';
import 'package:keek_news/use_case/feed_use_case.dart';

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
    final result = await sl<FeedUseCase>().getMergedFeed(
      const MergedFeedParams(),
    );
    _applyResult(result);
  }

  /// Silently refreshes page 1 without flipping to the loading skeleton.
  /// The current list stays visible during the fetch; on success it is
  /// replaced, on error it is preserved (no destructive state change).
  Future<void> refresh() async {
    final result = await sl<FeedUseCase>().getMergedFeed(
      const MergedFeedParams(),
    );
    result.fold(
      (_) {},
      (page) => state = MergedFeedState(
        items: page.items,
        cursor: page.next,
        hasMore: page.next?.hasMore ?? false,
        failedSources: page.failedSources,
      ),
    );
  }

  Future<void> fetchNextPage() async {
    if (state.isLoadingMore || !state.hasMore || state.cursor == null) return;

    state = state.copyWith(isLoadingMore: true);
    final result = await sl<FeedUseCase>().getMergedFeed(
      MergedFeedParams(cursor: state.cursor),
    );

    result.fold(
      (_) => state = state.copyWith(
        isLoadingMore: false,
        hasMore: state.cursor?.hasMore ?? false,
      ),
      (page) {
        final existingIds = state.items
            .map((e) => '${e.community}:${e.id}')
            .toSet();
        final newItems = page.items
            .where((e) => !existingIds.contains('${e.community}:${e.id}'))
            .toList();
        final cursor = page.next ?? state.cursor;
        state = MergedFeedState(
          items: [...state.items, ...newItems],
          cursor: cursor,
          hasMore: cursor?.hasMore ?? false,
          failedSources: page.failedSources,
        );
      },
    );
  }

  void _applyResult(Either<Failure, MergedPage> result) {
    result.fold(
      (f) => state = MergedFeedState(error: f.message),
      (page) => state = MergedFeedState(
        items: page.items,
        cursor: page.next,
        hasMore: page.next?.hasMore ?? false,
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

typedef MergedDetailKey = ({CommunityId community, String id});

typedef MergedDetailMap =
    Map<MergedDetailKey, AsyncValue<Either<Failure, PostDetail>>>;

class MergedDetailNotifier extends Notifier<MergedDetailMap> {
  @override
  MergedDetailMap build() => const {};

  Future<void> fetchDetail(MergedDetailKey key) async {
    if (state.containsKey(key)) {
      final existing = state[key]!;
      if (existing.isLoading || existing.hasValue) return;
    }
    state = {
      ...state,
      key: const AsyncValue<Either<Failure, PostDetail>>.loading(),
    };
    final result = await sl<FeedUseCase>().getPostDetail(
      community: key.community,
      id: key.id,
    );
    if (!state.containsKey(key)) return;
    state = {
      ...state,
      key: AsyncValue<Either<Failure, PostDetail>>.data(result),
    };
  }
}

final mergedDetailProvider =
    NotifierProvider<MergedDetailNotifier, MergedDetailMap>(
      MergedDetailNotifier.new,
    );
