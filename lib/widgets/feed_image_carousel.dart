import 'package:flutter/material.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/media_target.dart';
import 'package:keek_news/model/video_id.dart';
import 'package:keek_news/service/video_playback_controller.dart';
import 'package:keek_news/utils/image_aspect_resolver.dart';
import 'package:keek_news/widgets/inline_video_player.dart';
import 'package:keek_news/widgets/media_action_sheet.dart';
import 'package:keek_news/widgets/media_count_badge.dart';
import 'package:keek_news/widgets/retryable_network_image.dart';
import 'package:keek_news/widgets/video_thumbnail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class FeedImageCarousel extends StatefulWidget {
  const FeedImageCarousel({
    required this.imageUrls,
    required this.postId,
    this.videoBlocks = const [],
    this.onImageTap,
    this.videoController,
    super.key,
  });
  final List<String> imageUrls;
  final int postId;
  final List<VideoBlock> videoBlocks;
  final ValueChanged<int>? onImageTap;
  final VideoPlaybackController? videoController;

  @override
  State<FeedImageCarousel> createState() => _FeedImageCarouselState();
}

class _FeedImageCarouselState extends State<FeedImageCarousel> {
  static final _AspectCache _aspectCache = _AspectCache(maxEntries: 200);

  final PageController _controller = PageController();
  final Set<String> _hashBlockedUrls = <String>{};
  int _page = 0;
  int? _expandedVideoIndex;

  /// Visible image pages as (original index, url) pairs. Fingerprint-blocked
  /// URLs drop out at render time; the original index keeps onImageTap
  /// aligned with the unfiltered list the image viewer pages through.
  List<(int, String)> get _visibleImagePages => [
    for (var i = 0; i < widget.imageUrls.length; i++)
      if (!_hashBlockedUrls.contains(widget.imageUrls[i]))
        (i, widget.imageUrls[i]),
  ];

  int get _totalCount => _visibleImagePages.length + widget.videoBlocks.length;

  String? get _currentMediaUrl {
    final images = _visibleImagePages;
    if (_page < images.length) {
      return images[_page].$2;
    }
    final vi = _page - images.length;
    if (vi < widget.videoBlocks.length) {
      return widget.videoBlocks[vi].thumbnailUrl;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureAll());
  }

  @override
  void didUpdateWidget(covariant FeedImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The media list can shrink mid-session (blocked images are filtered at
    // the view layer or dropped after a fingerprint match). Keep the visible
    // page index inside the new bounds.
    _clampVisiblePage();
  }

  /// Keeps [_page] inside the current media bounds after the visible list
  /// shrinks, then re-syncs the PageController post-frame. Mutating [_page]
  /// outside setState is safe: callers run during (or just before) a
  /// scheduled rebuild that reads it.
  void _clampVisiblePage() {
    final total = _totalCount;
    if (total > 0 && _page >= total) {
      final target = total - 1;
      _page = target;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) {
          _controller.jumpToPage(target);
        }
      });
    } else if (total == 0) {
      _page = 0;
    }
  }

  void _onImageHashBlocked(String url) {
    if (!mounted) return;
    setState(() => _hashBlockedUrls.add(url));
    _clampVisiblePage();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _measureAll() {
    for (final url in widget.imageUrls) {
      _measure(url);
    }
    for (final v in widget.videoBlocks) {
      if (v.thumbnailUrl != null) _measure(v.thumbnailUrl!);
    }
  }

  void _measure(String url) {
    if (_aspectCache.containsKey(url)) return;
    ImageAspectResolver.resolve(
      url,
      onResolved: (aspect) {
        if (!mounted) return;
        setState(() => _aspectCache[url] = aspect);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleImages = _visibleImagePages;
    final total = visibleImages.length + widget.videoBlocks.length;
    if (total == 0) {
      // Every image was fingerprint-blocked and no videos remain — collapse
      // instead of reserving a media slot (min height would be 120px).
      return const SizedBox.shrink();
    }
    final multiple = total > 1;
    final screenW = MediaQuery.sizeOf(context).width;
    final url = _currentMediaUrl;
    final aspect = (url != null ? _aspectCache[url] : null) ?? 1.0;
    const maxHeight = 600.0;
    final height = (screenW / aspect).clamp(120.0, maxHeight);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: PageView.builder(
              controller: _controller,
              itemCount: total,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, index) {
                if (index < visibleImages.length) {
                  return _buildImagePage(visibleImages[index]);
                }
                return _buildVideoPage(index - visibleImages.length);
              },
            ),
          ),
          if (multiple)
            Positioned(
              top: 8,
              right: 8,
              child: IgnorePointer(
                child: MediaCountBadge(text: '${_page + 1}/$total'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImagePage((int, String) page) {
    final (index, url) = page;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onImageTap == null ? null : () => widget.onImageTap!(index),
      onLongPress: () =>
          showMediaActionSheet(context, target: MediaTarget.image(url)),
      child: RetryableNetworkImage(
        imageUrl: url,
        width: double.infinity,
        fit: BoxFit.contain,
        onBlocked: () => _onImageHashBlocked(url),
      ),
    );
  }

  Widget _buildVideoPage(int index) {
    if (index == _expandedVideoIndex) {
      return InlineVideoPlayer(
        block: widget.videoBlocks[index],
        autoplay: true,
        videoId: VideoId(postId: widget.postId, blockIndex: index),
        controller: widget.videoController,
      );
    }
    final video = widget.videoBlocks[index];
    return GestureDetector(
      onLongPress: () =>
          showMediaActionSheet(context, target: MediaTarget.video(video)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (video.thumbnailUrl != null)
            // Video media is outside the image-block scope, and synthesized
            // posters (humoruniv thumb.php) share one fingerprint across all
            // videos — a single matching blocklist entry would hide them all.
            RetryableNetworkImage(
              imageUrl: video.thumbnailUrl!,
              fit: BoxFit.cover,
              placeholderColor: Colors.black,
              disableBlockFilter: true,
            )
          else
            VideoThumbnail(
              videoUrl: video.url,
              placeholderColor: Colors.black,
              showIcon: false,
            ),
          Center(
            child: Semantics(
              label: '재생',
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _expandedVideoIndex = index),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.play,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple bounded LRU map. Sufficient for the aspect cache.
class _AspectCache {
  _AspectCache({required this.maxEntries});
  final int maxEntries;
  final Map<String, double> _map = <String, double>{};

  bool containsKey(String key) => _map.containsKey(key);

  double? operator [](String key) {
    final value = _map.remove(key);
    if (value == null) return null;
    _map[key] = value;
    return value;
  }

  void operator []=(String key, double value) {
    _map.remove(key);
    _map[key] = value;
    if (_map.length > maxEntries) {
      _map.remove(_map.keys.first);
    }
  }
}
