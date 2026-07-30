import 'package:equatable/equatable.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/feed_item.dart';

class MergedCursor extends Equatable {
  const MergedCursor({required this.oldestSeen, required this.perSourceTokens});

  final DateTime oldestSeen;
  final Map<CommunityId, String?> perSourceTokens;

  @override
  List<Object?> get props => [
    oldestSeen,
    ...perSourceTokens.entries.map((e) => [e.key, e.value]),
  ];
}

class MergedPage extends Equatable {
  const MergedPage({
    required this.items,
    this.next,
    this.failedSources = const {},
  });

  final List<FeedItem> items;
  final MergedCursor? next;
  final Set<CommunityId> failedSources;

  @override
  List<Object?> get props => [items, next, failedSources.toList()];
}
