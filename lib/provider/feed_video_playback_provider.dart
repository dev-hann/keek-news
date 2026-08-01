import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keek_news/model/video_id.dart';
import 'package:keek_news/service/video_playback_controller.dart';

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

class VideoPlaybackControllerNotifier
    extends Notifier<VideoPlaybackController> {
  @override
  VideoPlaybackController build() {
    final active = ValueNotifier<VideoId?>(ref.read(feedVideoPlaybackProvider));
    ref.listen<VideoId?>(feedVideoPlaybackProvider, (previous, next) {
      if (active.value != next) active.value = next;
    });
    ref.onDispose(active.dispose);
    return ValueNotifierVideoPlaybackController(
      active,
      (id) => ref.read(feedVideoPlaybackProvider.notifier).setActive(id),
    );
  }
}

final videoPlaybackControllerProvider =
    NotifierProvider<VideoPlaybackControllerNotifier, VideoPlaybackController>(
      VideoPlaybackControllerNotifier.new,
    );
