import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/video_id.dart';
import 'package:keek_news/provider/feed_video_playback_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  group('FeedVideoPlaybackNotifier', () {
    test('initial activeVideoId is null', () {
      expect(container.read(feedVideoPlaybackProvider), isNull);
    });

    test('setActive stores the given VideoId', () {
      const id = VideoId(postId: 1, blockIndex: 0);
      container.read(feedVideoPlaybackProvider.notifier).setActive(id);
      expect(container.read(feedVideoPlaybackProvider), id);
    });

    test('setActive replaces the previous VideoId (single-slot)', () {
      const a = VideoId(postId: 1, blockIndex: 0);
      const b = VideoId(postId: 2, blockIndex: 0);
      container.read(feedVideoPlaybackProvider.notifier).setActive(a);
      container.read(feedVideoPlaybackProvider.notifier).setActive(b);
      expect(container.read(feedVideoPlaybackProvider), b);
    });

    test('different post/block produce different VideoIds', () {
      expect(
        const VideoId(postId: 1, blockIndex: 0) ==
            const VideoId(postId: 1, blockIndex: 1),
        isFalse,
      );
      expect(
        const VideoId(postId: 1, blockIndex: 0).hashCode ==
            const VideoId(postId: 2, blockIndex: 0).hashCode,
        isFalse,
      );
    });
  });
}
