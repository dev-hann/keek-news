import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/merged_feed.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/repository/merged_feed/merged_feed_repo.dart';
import 'package:keek_news/service/service_locator.dart';
import 'package:keek_news/use_case/get_merged_feed_use_case.dart';

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
    final result = await sl<GetMergedFeedUseCase>()(const MergedFeedParams());
    _applyResult(result);
  }

  Future<void> fetchNextPage() async {
    if (state.isLoadingMore || !state.hasMore || state.cursor == null) return;

    state = state.copyWith(isLoadingMore: true);
    final result = await sl<GetMergedFeedUseCase>()(
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
      return sl<MergedFeedRepo>().fetchDetail(
        community: key.community,
        id: key.id,
      );
    });
