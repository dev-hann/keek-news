import 'dart:async';

import 'package:flutter/material.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/video_id.dart';
import 'package:keek_news/service/video_playback_controller.dart';
import 'package:keek_news/widgets/retryable_network_image.dart';
import 'package:keek_news/widgets/video_buffering_overlay.dart';
import 'package:keek_news/widgets/video_error_view.dart';
import 'package:keek_news/widgets/video_surface.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

const Duration _kControlsHideDelay = Duration(seconds: 3);
const double _kPauseThreshold = 0.4;
const double _kMinTouchTarget = 44;
const double _kIconLarge = 24;
const Color _scrimForeground = Colors.white;
const Color _mediaSurface = Colors.black;
const Color _imagePlaceholder = Color(0xFF1a1a1a);

mixin _VideoPlayerControllerMixin<T extends StatefulWidget> on State<T> {
  VideoPlayerController? controller;
  bool isInitialized = false;
  bool hasError = false;
  bool isBuffering = false;
  bool showPlayButton = true;
  bool showControls = true;
  bool isMuted = true;
  Timer? hideTimer;

  VideoBlock get videoBlock;

  bool get isPlaying =>
      isInitialized && controller != null && controller!.value.isPlaying;

  void onAfterInit() {}

  void onPlay() {}

  void _onValueChange() {
    final c = controller;
    if (!mounted || c == null) return;
    final buffering = c.value.isBuffering;
    if (buffering != isBuffering) {
      setState(() => isBuffering = buffering);
    }
  }

  void pauseIfPlaying() {
    final c = controller;
    if (isInitialized && c != null && c.value.isPlaying) {
      c.pause();
      setState(() => showPlayButton = true);
    }
  }

  void initController({Duration? initialPosition}) {
    final c = VideoPlayerController.networkUrl(Uri.parse(videoBlock.url));
    controller = c
      ..addListener(_onValueChange)
      ..initialize()
          .then((_) {
            if (!mounted || controller != c) return;
            setState(() => isInitialized = true);
            controller!.setLooping(true);
            controller!.setVolume(isMuted ? 0 : 1);
            if (initialPosition != null && initialPosition > Duration.zero) {
              controller!.seekTo(initialPosition);
            }
            onAfterInit();
            startHideTimer();
          })
          .catchError((_) {
            if (!mounted || controller != c) return;
            setState(() => hasError = true);
          });
  }

  /// Disposes the current controller and re-initializes from scratch. Used by
  /// the error view's "탭하여 재시도" affordance.
  void retryInit() {
    final old = controller;
    if (old != null) {
      old.removeListener(_onValueChange);
      old.dispose();
    }
    if (!mounted) return;
    setState(() {
      controller = null;
      hasError = false;
      isInitialized = false;
      isBuffering = false;
      showPlayButton = true;
      showControls = true;
    });
    initController();
  }

  void startHideTimer() {
    hideTimer?.cancel();
    hideTimer = Timer(_kControlsHideDelay, () {
      if (mounted && isPlaying) {
        setState(() => showControls = false);
      }
    });
  }

  void cancelHideTimer() => hideTimer?.cancel();

  void handleVideoTap() {
    setState(() => showControls = !showControls);
    if (showControls && isPlaying) {
      startHideTimer();
    } else {
      cancelHideTimer();
    }
  }

  void togglePlayPause() {
    final c = controller;
    if (c == null || !isInitialized) return;
    setState(() {
      if (c.value.isPlaying) {
        c.pause();
        showPlayButton = true;
        cancelHideTimer();
      } else {
        c.play();
        showPlayButton = false;
        onPlay();
        startHideTimer();
      }
    });
  }

  void toggleMute() {
    final c = controller;
    if (c == null || !isInitialized) return;
    setState(() {
      isMuted = !isMuted;
      c.setVolume(isMuted ? 0 : 1);
    });
  }

  @override
  void dispose() {
    hideTimer?.cancel();
    controller?.removeListener(_onValueChange);
    controller?.dispose();
    super.dispose();
  }

  String formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString();
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget buildCenterPlayIcon() {
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
          isPlaying ? LucideIcons.pause : LucideIcons.play,
          size: 40,
          color: _scrimForeground,
        ),
      ),
    );
  }

  Widget buildBottomControls(
    Duration position,
    Duration duration, {
    VoidCallback? onFullscreen,
    EdgeInsets bottomPadding = const EdgeInsets.all(4),
  }) {
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
        bottom: bottomPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isInitialized && controller != null)
            VideoProgressIndicator(
              controller!,
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
                width: _kMinTouchTarget,
                height: _kMinTouchTarget,
                child: IconButton(
                  tooltip: isPlaying ? '일시정지' : '재생',
                  icon: Icon(
                    isPlaying ? LucideIcons.pause : LucideIcons.play,
                    color: _scrimForeground,
                    size: _kIconLarge,
                  ),
                  onPressed: isInitialized ? togglePlayPause : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: _kMinTouchTarget,
                    minHeight: _kMinTouchTarget,
                  ),
                ),
              ),
              Text(
                '${formatDuration(position)} / ${formatDuration(duration)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: _scrimForeground),
              ),
              const Spacer(),
              SizedBox(
                width: _kMinTouchTarget,
                height: _kMinTouchTarget,
                child: IconButton(
                  tooltip: isMuted ? '음소거 해제' : '음소거',
                  icon: Icon(
                    isMuted ? LucideIcons.volumeX : LucideIcons.volume2,
                    color: _scrimForeground,
                    size: _kIconLarge,
                  ),
                  onPressed: isInitialized ? toggleMute : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: _kMinTouchTarget,
                    minHeight: _kMinTouchTarget,
                  ),
                ),
              ),
              if (onFullscreen != null)
                SizedBox(
                  width: _kMinTouchTarget,
                  height: _kMinTouchTarget,
                  child: IconButton(
                    tooltip: '전체 화면',
                    icon: const Icon(
                      LucideIcons.maximize,
                      color: _scrimForeground,
                      size: _kIconLarge,
                    ),
                    onPressed: onFullscreen,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: _kMinTouchTarget,
                      minHeight: _kMinTouchTarget,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class InlineVideoPlayer extends StatefulWidget {
  const InlineVideoPlayer({
    required this.block,
    this.autoplay = false,
    this.videoId,
    this.controller,
    super.key,
  });
  final VideoBlock block;
  final bool autoplay;
  final VideoId? videoId;
  final VideoPlaybackController? controller;

  @override
  State<InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<InlineVideoPlayer>
    with _VideoPlayerControllerMixin<InlineVideoPlayer> {
  @override
  VideoBlock get videoBlock => widget.block;

  @override
  void initState() {
    super.initState();
    widget.controller?.activeVideo.addListener(_onActiveChanged);
    initController();
  }

  @override
  void didUpdateWidget(covariant InlineVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.activeVideo.removeListener(_onActiveChanged);
      widget.controller?.activeVideo.addListener(_onActiveChanged);
    }
  }

  @override
  void onAfterInit() {
    if (widget.autoplay) {
      controller!.play();
      showPlayButton = false;
      final id = widget.videoId;
      if (id != null) {
        widget.controller?.setActive(id);
      }
    }
  }

  @override
  void onPlay() {
    final id = widget.videoId;
    if (id != null) {
      widget.controller?.setActive(id);
    }
  }

  void _onActiveChanged() {
    final id = widget.videoId;
    if (id == null) return;
    final active = widget.controller?.activeVideo.value;
    if (active != id) {
      pauseIfPlaying();
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final id = widget.videoId;
    if (id == null) return;
    if (info.visibleFraction < _kPauseThreshold) {
      pauseIfPlaying();
    }
  }

  void _enterFullscreen() {
    if (!mounted || controller == null) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _FullscreenVideoPlayer(
          block: widget.block,
          initialPosition: controller!.value.position,
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.controller?.activeVideo.removeListener(_onActiveChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGif = widget.block.isGifConversion;
    final position = controller?.value.position ?? Duration.zero;
    final duration = controller?.value.duration ?? Duration.zero;

    final player = GestureDetector(
      onTap: isInitialized ? handleVideoTap : null,
      child: AspectRatio(
        aspectRatio: isInitialized ? controller!.value.aspectRatio : 16 / 9,
        child: ColoredBox(
          color: _mediaSurface,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (hasError)
                VideoErrorView(onRetry: retryInit)
              else if (isInitialized)
                VideoSurface(controller: controller!)
              else if (widget.block.thumbnailUrl != null)
                RetryableNetworkImage(
                  imageUrl: widget.block.thumbnailUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholderColor: _mediaSurface,
                  foregroundColor: _scrimForeground,
                )
              else
                _buildLoading(),
              VideoBufferingOverlay(visible: isBuffering),
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

  Widget _buildLoading() {
    return const ColoredBox(
      color: _imagePlaceholder,
      child: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }

  Widget _buildGifOverlay() {
    if (!showPlayButton) return const SizedBox.shrink();
    return GestureDetector(
      onTap: isInitialized ? togglePlayPause : null,
      child: buildCenterPlayIcon(),
    );
  }

  Widget _buildControlsOverlay(Duration position, Duration duration) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: isInitialized ? handleVideoTap : null,
            behavior: HitTestBehavior.translucent,
          ),
        ),
        IgnorePointer(
          ignoring: !showControls,
          child: AnimatedOpacity(
            opacity: showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (showPlayButton)
                  Center(
                    child: GestureDetector(
                      onTap: isInitialized ? togglePlayPause : null,
                      child: buildCenterPlayIcon(),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: buildBottomControls(
                    position,
                    duration,
                    onFullscreen: _enterFullscreen,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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

class _FullscreenVideoPlayerState extends State<_FullscreenVideoPlayer>
    with _VideoPlayerControllerMixin<_FullscreenVideoPlayer> {
  @override
  VideoBlock get videoBlock => widget.block;

  @override
  void initState() {
    super.initState();
    initController(initialPosition: widget.initialPosition);
  }

  @override
  Widget build(BuildContext context) {
    final position = controller?.value.position ?? Duration.zero;
    final duration = controller?.value.duration ?? Duration.zero;

    return Scaffold(
      backgroundColor: _mediaSurface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: isInitialized ? handleVideoTap : null,
            child: Center(
              child: AspectRatio(
                aspectRatio: isInitialized
                    ? controller!.value.aspectRatio
                    : 16 / 9,
                child: ColoredBox(
                  color: _mediaSurface,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (hasError)
                        VideoErrorView(onRetry: retryInit)
                      else if (isInitialized)
                        VideoSurface(controller: controller!)
                      else if (widget.block.thumbnailUrl != null)
                        RetryableNetworkImage(
                          imageUrl: widget.block.thumbnailUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholderColor: _mediaSurface,
                          foregroundColor: _scrimForeground,
                        )
                      else
                        const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      VideoBufferingOverlay(visible: isBuffering),
                      IgnorePointer(
                        ignoring: !showControls,
                        child: AnimatedOpacity(
                          opacity: showControls ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 250),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (showPlayButton)
                                Center(
                                  child: GestureDetector(
                                    onTap: isInitialized
                                        ? togglePlayPause
                                        : null,
                                    child: buildCenterPlayIcon(),
                                  ),
                                ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: buildBottomControls(
                                  position,
                                  duration,
                                  bottomPadding: EdgeInsets.only(
                                    bottom:
                                        MediaQuery.of(context).padding.bottom +
                                        4,
                                  ),
                                ),
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
            width: _kMinTouchTarget,
            height: _kMinTouchTarget,
            child: IconButton(
              tooltip: '닫기',
              icon: const Icon(
                LucideIcons.x,
                color: _scrimForeground,
                size: _kIconLarge,
              ),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: _kMinTouchTarget,
                minHeight: _kMinTouchTarget,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
