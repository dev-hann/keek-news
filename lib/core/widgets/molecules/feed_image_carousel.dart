import 'package:flutter/material.dart';

import 'package:happy_news/core/providers/feed_video_playback_provider.dart';
import 'package:happy_news/core/themes/app_colors.dart';
import 'package:happy_news/core/themes/app_durations.dart';
import 'package:happy_news/core/themes/app_radius.dart';
import 'package:happy_news/core/themes/app_sizes.dart';
import 'package:happy_news/core/themes/app_spacing.dart';
import 'package:happy_news/core/widgets/atoms/retryable_network_image.dart';
import 'package:happy_news/core/widgets/atoms/video_thumbnail.dart';
import 'package:happy_news/core/widgets/molecules/inline_video_player.dart';
import 'package:happy_news/domain/entities/content_block.dart';

class FeedImageCarousel extends StatefulWidget {
  const FeedImageCarousel({
    required this.imageUrls,
    required this.postId,
    this.videoBlocks = const [],
    this.onImageTap,
    super.key,
  });
  final List<String> imageUrls;
  final int postId;
  final List<VideoBlock> videoBlocks;
  final ValueChanged<int>? onImageTap;

  @override
  State<FeedImageCarousel> createState() => _FeedImageCarouselState();
}

class _FeedImageCarouselState extends State<FeedImageCarousel> {
  final PageController _controller = PageController();
  int _page = 0;
  int? _expandedVideoIndex;

  /// Process-lifetime LRU cache of measured image aspect ratios so the
  /// carousel can size itself correctly before images finish loading.
  /// Bounded to avoid unbounded growth as the user scrolls the feed.
  static final _AspectCache _aspectCache = _AspectCache(maxEntries: 200);

  int get _totalCount => widget.imageUrls.length + widget.videoBlocks.length;

  String? get _currentMediaUrl {
    if (_page < widget.imageUrls.length) {
      return widget.imageUrls[_page];
    }
    final vi = _page - widget.imageUrls.length;
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
    final stream = NetworkImage(url).resolve(const ImageConfiguration());
    ImageStreamListener? listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!mounted || listener == null) return;
        setState(() {
          _aspectCache[url] =
              info.image.width.toDouble() / info.image.height.toDouble();
        });
        stream.removeListener(listener);
      },
      onError: (exception, stackTrace) {
        if (listener != null) stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalCount;
    final multiple = total > 1;
    final screenW = MediaQuery.sizeOf(context).width;
    final url = _currentMediaUrl;
    final aspect = (url != null ? _aspectCache[url] : null) ?? 1.0;
    final height = (screenW / aspect).clamp(120.0, AppSizes.feedMediaMaxHeight);

    return AnimatedContainer(
      duration: AppDurations.medium,
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
                if (index < widget.imageUrls.length) {
                  return _buildImagePage(index);
                }
                return _buildVideoPage(index - widget.imageUrls.length);
              },
            ),
          ),
          if (multiple)
            Positioned(
              top: AppSpacing.p8,
              right: AppSpacing.p8,
              child: IgnorePointer(
                child: Container(
                  padding: AppSpacing.edgeH8V4,
                  decoration: const BoxDecoration(
                    color: AppColors.imageViewerOverlay,
                    borderRadius: AppRadius.borderRadiusLg,
                  ),
                  child: Text(
                    '${_page + 1}/$total',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.imageViewerForeground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImagePage(int index) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onImageTap == null ? null : () => widget.onImageTap!(index),
      child: RetryableNetworkImage(
        imageUrl: widget.imageUrls[index],
        width: double.infinity,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildVideoPage(int index) {
    if (index == _expandedVideoIndex) {
      return InlineVideoPlayer(
        block: widget.videoBlocks[index],
        autoplay: true,
        videoId: VideoId(postId: widget.postId, blockIndex: index),
      );
    }
    final video = widget.videoBlocks[index];
    return Stack(
      fit: StackFit.expand,
      children: [
        if (video.thumbnailUrl != null)
          RetryableNetworkImage(
            imageUrl: video.thumbnailUrl!,
            fit: BoxFit.cover,
            placeholderColor: AppColors.mediaSurface,
          )
        else
          VideoThumbnail(
            videoUrl: video.url,
            placeholderColor: AppColors.mediaSurface,
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
                  color: AppColors.imageViewerOverlay,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: AppColors.imageViewerForeground,
                  size: 40,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Simple bounded LRU map: removes the least recently accessed entry when
/// [maxEntries] is exceeded. Sufficient for the aspect cache where we only
/// need [containsKey]/read/write.
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
