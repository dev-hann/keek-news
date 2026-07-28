import 'package:flutter/foundation.dart';
import 'package:humoruniv/domain/entities/community.dart';
import 'package:humoruniv/domain/entities/feed_item.dart';
import 'package:meta/meta.dart';

@immutable
class MergedCursor {
  const MergedCursor({required this.oldestSeen, required this.perSourceTokens});

  final DateTime oldestSeen;
  final Map<CommunityId, String?> perSourceTokens;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MergedCursor &&
          runtimeType == other.runtimeType &&
          oldestSeen == other.oldestSeen &&
          mapEquals(perSourceTokens, other.perSourceTokens);

  @override
  int get hashCode => oldestSeen.hashCode;
}

@immutable
class MergedPage {
  const MergedPage({
    required this.items,
    this.next,
    this.failedSources = const {},
  });

  final List<FeedItem> items;
  final MergedCursor? next;
  final Set<CommunityId> failedSources;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MergedPage &&
          runtimeType == other.runtimeType &&
          items == other.items &&
          next == other.next &&
          failedSources.length == other.failedSources.length &&
          failedSources.containsAll(other.failedSources);

  @override
  int get hashCode => Object.hash(items, next, failedSources);
}
