import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happy_news/core/providers/feed_video_playback_provider.dart';
import 'package:happy_news/core/themes/app_colors.dart';
import 'package:happy_news/core/themes/app_durations.dart';
import 'package:happy_news/core/themes/app_sizes.dart';
import 'package:happy_news/core/widgets/atoms/retryable_network_image.dart';
import 'package:happy_news/core/widgets/atoms/video_surface.dart';
import 'package:happy_news/domain/entities/content_block.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

const Duration _kControlsHideDelay = Duration(seconds: 3);

class InlineVideoPlayer extends ConsumerStatefulWidget {
  const InlineVideoPlayer({
    required this.block,
    this.autoplay = false,
    this.videoId,
    super.key,
  });
  final VideoBlock block;
  final bool autoplay;
  final VideoId? videoId;

  @override
  ConsumerState<InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends ConsumerState<InlineVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showPlayButton = true;
  bool _showControls = true;
  bool _isMuted = true;
  Timer? _hideTimer;

  static const double _kPauseThreshold = 0.4;

  @override
  void initState() {
    super.initState();
    ref.listenManual<VideoId?>(feedVideoPlaybackProvider, _onActiveChanged);
    _initController();
  }

  void _onActiveChanged(VideoId? previous, VideoId? next) {
    final id = widget.videoId;
    if (id == null) return;
    if (next != id &&
        _isInitialized &&
        _controller != null &&
        _controller!.value.isPlaying) {
      _controller!.pause();
      setState(() => _showPlayButton = true);
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final id = widget.videoId;
    if (id == null) return;
    if (info.visibleFraction < _kPauseThreshold &&
        _isInitialized &&
        _controller != null &&
        _controller!.value.isPlaying) {
      _controller!.pause();
      setState(() => _showPlayButton = true);
    }
  }

  void _initController() {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.block.url))
      ..initialize()
          .then((_) {
            if (mounted) {
              setState(() => _isInitialized = true);
              _controller!.setLooping(true);
              _controller!.setVolume(_isMuted ? 0 : 1);
              if (widget.autoplay) {
                _controller!.play();
                _showPlayButton = false;
                final id = widget.videoId;
                if (id != null) {
                  ref.read(feedVideoPlaybackProvider.notifier).setActive(id);
                }
              }
              _startHideTimer();
            }
          })
          .catchError((_) {
            if (mounted) {
              setState(() => _hasError = true);
            }
          });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_kControlsHideDelay, () {
      if (mounted &&
          _isInitialized &&
          _controller != null &&
          _controller!.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _cancelHideTimer() => _hideTimer?.cancel();

  void _handleVideoTap() {
    setState(() => _showControls = !_showControls);
    if (_showControls &&
        _isInitialized &&
        _controller != null &&
        _controller!.value.isPlaying) {
      _startHideTimer();
    } else {
      _cancelHideTimer();
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _showPlayButton = true;
        _cancelHideTimer();
      } else {
        _controller!.play();
        _showPlayButton = false;
        final id = widget.videoId;
        if (id != null) {
          ref.read(feedVideoPlaybackProvider.notifier).setActive(id);
        }
        _startHideTimer();
      }
    });
  }

  void _toggleMute() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0 : 1);
    });
  }

  void _enterFullscreen() {
    if (!mounted || _controller == null) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _FullscreenVideoPlayer(
          block: widget.block,
          initialPosition: _controller!.value.position,
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString();
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isGif = widget.block.isGifConversion;
    final position = _controller?.value.position ?? Duration.zero;
    final duration = _controller?.value.duration ?? Duration.zero;

    final player = GestureDetector(
      onTap: _isInitialized ? _handleVideoTap : null,
      child: AspectRatio(
        aspectRatio: _isInitialized ? _controller!.value.aspectRatio : 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_hasError)
                _buildError()
              else if (_isInitialized)
                VideoSurface(controller: _controller!)
              else if (widget.block.thumbnailUrl != null)
                RetryableNetworkImage(
                  imageUrl: widget.block.thumbnailUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholderColor: Colors.black,
                  foregroundColor: AppColors.imageViewerForeground,
                )
              else
                _buildLoading(),
              if (!_hasError && !_isInitialized && !_showPlayButton)
                const CircularProgressIndicator(color: Colors.white),
              if (isGif)
                _buildGifOverlay()
              else
                _buildControlsOverlay(position, duration),
            ],
          ),
        ),
      ),
    );

    final id = widget.videoId;
    if (id == null) return player;
    return VisibilityDetector(
      key: ValueKey('inline-video-${id.postId}-${id.blockIndex}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: player,
    );
  }

  Widget _buildGifOverlay() {
    if (!_showPlayButton) return const SizedBox.shrink();
    return GestureDetector(
      onTap: _isInitialized ? _togglePlayPause : null,
      child: _buildCenterPlayIcon(),
    );
  }

  Widget _buildControlsOverlay(Duration position, Duration duration) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _isInitialized ? _handleVideoTap : null,
            behavior: HitTestBehavior.translucent,
          ),
        ),
        IgnorePointer(
          ignoring: !_showControls,
          child: AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: AppDurations.medium,
            curve: AppCurves.standard,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_showPlayButton)
                  Center(
                    child: GestureDetector(
                      onTap: _isInitialized ? _togglePlayPause : null,
                      child: _buildCenterPlayIcon(),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildBottomControls(position, duration),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCenterPlayIcon() {
    final isPlaying =
        _isInitialized && _controller != null && _controller!.value.isPlaying;
    return Semantics(
      button: true,
      label: isPlaying ? '일시정지' : '재생',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(12),
        child: Icon(
          isPlaying ? Icons.pause : Icons.play_arrow,
          size: 40,
          color: AppColors.imageViewerForeground,
        ),
      ),
    );
  }

  Widget _buildBottomControls(Duration position, Duration duration) {
    final isPlaying =
        _isInitialized && _controller != null && _controller!.value.isPlaying;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
        ),
      ),
      padding: const EdgeInsets.only(top: 24, left: 4, right: 4, bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isInitialized && _controller != null)
            VideoProgressIndicator(
              _controller!,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: Theme.of(context).colorScheme.primary,
                bufferedColor: Colors.white.withValues(alpha: 0.3),
                backgroundColor: Colors.white.withValues(alpha: 0.2),
              ),
            ),
          Row(
            children: [
              SizedBox(
                width: AppSizes.minTouchTarget,
                height: AppSizes.minTouchTarget,
                child: IconButton(
                  tooltip: isPlaying ? '일시정지' : '재생',
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: AppColors.imageViewerForeground,
                    size: AppSizes.iconLarge,
                  ),
                  onPressed: _isInitialized ? _togglePlayPause : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: AppSizes.minTouchTarget,
                    minHeight: AppSizes.minTouchTarget,
                  ),
                ),
              ),
              Text(
                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.imageViewerForeground,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: AppSizes.minTouchTarget,
                height: AppSizes.minTouchTarget,
                child: IconButton(
                  tooltip: _isMuted ? '음소거 해제' : '음소거',
                  icon: Icon(
                    _isMuted ? Icons.volume_off : Icons.volume_up,
                    color: AppColors.imageViewerForeground,
                    size: AppSizes.iconLarge,
                  ),
                  onPressed: _isInitialized ? _toggleMute : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: AppSizes.minTouchTarget,
                    minHeight: AppSizes.minTouchTarget,
                  ),
                ),
              ),
              SizedBox(
                width: AppSizes.minTouchTarget,
                height: AppSizes.minTouchTarget,
                child: IconButton(
                  tooltip: '전체 화면',
                  icon: const Icon(
                    Icons.fullscreen,
                    color: AppColors.imageViewerForeground,
                    size: AppSizes.iconLarge,
                  ),
                  onPressed: _enterFullscreen,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: AppSizes.minTouchTarget,
                    minHeight: AppSizes.minTouchTarget,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const ColoredBox(
      color: AppColors.imagePlaceholder,
      child: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }

  Widget _buildError() {
    return const ColoredBox(
      color: AppColors.imagePlaceholder,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.white54, size: 32),
            SizedBox(height: 8),
            Text('동영상을 불러올 수 없습니다', style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

class _FullscreenVideoPlayer extends StatefulWidget {
  const _FullscreenVideoPlayer({
    required this.block,
    required this.initialPosition,
  });
  final VideoBlock block;
  final Duration initialPosition;

  @override
  State<_FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<_FullscreenVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showPlayButton = true;
  bool _showControls = true;
  bool _isMuted = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.block.url))
      ..initialize()
          .then((_) {
            if (mounted) {
              setState(() => _isInitialized = true);
              _controller!.setLooping(true);
              _controller!.setVolume(0);
              if (widget.initialPosition > Duration.zero) {
                _controller!.seekTo(widget.initialPosition);
              }
              _startHideTimer();
            }
          })
          .catchError((_) {
            if (mounted) {
              setState(() => _hasError = true);
            }
          });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_kControlsHideDelay, () {
      if (mounted &&
          _isInitialized &&
          _controller != null &&
          _controller!.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _cancelHideTimer() => _hideTimer?.cancel();

  void _handleVideoTap() {
    setState(() => _showControls = !_showControls);
    if (_showControls &&
        _isInitialized &&
        _controller != null &&
        _controller!.value.isPlaying) {
      _startHideTimer();
    } else {
      _cancelHideTimer();
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _showPlayButton = true;
        _cancelHideTimer();
      } else {
        _controller!.play();
        _showPlayButton = false;
        _startHideTimer();
      }
    });
  }

  void _toggleMute() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0 : 1);
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString();
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final position = _controller?.value.position ?? Duration.zero;
    final duration = _controller?.value.duration ?? Duration.zero;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: _isInitialized ? _handleVideoTap : null,
            child: Center(
              child: AspectRatio(
                aspectRatio: _isInitialized
                    ? _controller!.value.aspectRatio
                    : 16 / 9,
                child: ColoredBox(
                  color: Colors.black,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_hasError)
                        _buildError()
                      else if (_isInitialized)
                        VideoSurface(controller: _controller!)
                      else
                        const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      IgnorePointer(
                        ignoring: !_showControls,
                        child: AnimatedOpacity(
                          opacity: _showControls ? 1.0 : 0.0,
                          duration: AppDurations.medium,
                          curve: AppCurves.standard,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (_showPlayButton)
                                Center(
                                  child: GestureDetector(
                                    onTap: _isInitialized
                                        ? _togglePlayPause
                                        : null,
                                    child: _buildCenterPlayIcon(),
                                  ),
                                ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: _buildBottomControls(position, duration),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: 0,
                                child: _buildTopBar(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterPlayIcon() {
    final isPlaying =
        _isInitialized && _controller != null && _controller!.value.isPlaying;
    return Semantics(
      button: true,
      label: isPlaying ? '일시정지' : '재생',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(12),
        child: Icon(
          isPlaying ? Icons.pause : Icons.play_arrow,
          size: 40,
          color: AppColors.imageViewerForeground,
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        left: 4,
        right: 4,
        bottom: 8,
      ),
      child: Row(
        children: [
          SizedBox(
            width: AppSizes.minTouchTarget,
            height: AppSizes.minTouchTarget,
            child: IconButton(
              tooltip: '닫기',
              icon: const Icon(
                Icons.close,
                color: AppColors.imageViewerForeground,
                size: AppSizes.iconLarge,
              ),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: AppSizes.minTouchTarget,
                minHeight: AppSizes.minTouchTarget,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(Duration position, Duration duration) {
    final isPlaying =
        _isInitialized && _controller != null && _controller!.value.isPlaying;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
        ),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 4,
        right: 4,
        bottom: MediaQuery.of(context).padding.bottom + 4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isInitialized && _controller != null)
            VideoProgressIndicator(
              _controller!,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: Theme.of(context).colorScheme.primary,
                bufferedColor: Colors.white.withValues(alpha: 0.3),
                backgroundColor: Colors.white.withValues(alpha: 0.2),
              ),
            ),
          Row(
            children: [
              SizedBox(
                width: AppSizes.minTouchTarget,
                height: AppSizes.minTouchTarget,
                child: IconButton(
                  tooltip: isPlaying ? '일시정지' : '재생',
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: AppColors.imageViewerForeground,
                    size: AppSizes.iconLarge,
                  ),
                  onPressed: _isInitialized ? _togglePlayPause : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: AppSizes.minTouchTarget,
                    minHeight: AppSizes.minTouchTarget,
                  ),
                ),
              ),
              Text(
                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.imageViewerForeground,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: AppSizes.minTouchTarget,
                height: AppSizes.minTouchTarget,
                child: IconButton(
                  tooltip: _isMuted ? '음소거 해제' : '음소거',
                  icon: Icon(
                    _isMuted ? Icons.volume_off : Icons.volume_up,
                    color: AppColors.imageViewerForeground,
                    size: AppSizes.iconLarge,
                  ),
                  onPressed: _isInitialized ? _toggleMute : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: AppSizes.minTouchTarget,
                    minHeight: AppSizes.minTouchTarget,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return const ColoredBox(
      color: AppColors.imagePlaceholder,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.white54, size: 32),
            SizedBox(height: 8),
            Text('동영상을 불러올 수 없습니다', style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}
