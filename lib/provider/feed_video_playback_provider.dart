import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

@immutable
class VideoId {
  const VideoId({required this.postId, required this.blockIndex});
  final int postId;
  final int blockIndex;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoId &&
          postId == other.postId &&
          blockIndex == other.blockIndex;

  @override
  int get hashCode => Object.hash(postId, blockIndex);
}

class FeedVideoPlaybackNotifier extends Notifier<VideoId?> {
  @override
  VideoId? build() => null;

  void setActive(VideoId id) {
    if (state == id) return;
    state = id;
  }
}

final feedVideoPlaybackProvider =
    NotifierProvider<FeedVideoPlaybackNotifier, VideoId?>(
      FeedVideoPlaybackNotifier.new,
    );
