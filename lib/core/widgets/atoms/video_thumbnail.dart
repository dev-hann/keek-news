import 'package:flutter/material.dart';
import 'package:happy_news/core/themes/app_colors.dart';
import 'package:happy_news/core/widgets/atoms/video_surface.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

const double _kVisibleThreshold = 0.4;

class VideoThumbnail extends StatefulWidget {
  const VideoThumbnail({
    required this.videoUrl,
    this.fit = BoxFit.cover,
    this.placeholderColor,
    super.key,
  });

  final String videoUrl;
  final BoxFit fit;
  final Color? placeholderColor;

  @override
  State<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  bool _armed = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (info.visibleFraction >= _kVisibleThreshold) {
      _arm();
    } else if (_armed && !_initialized) {
      _disarm();
    }
  }

  void _arm() {
    if (_armed) return;
    _armed = true;
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize()
          .then((_) {
            if (!mounted) {
              _controller?.dispose();
              return;
            }
            setState(() {
              _initialized = true;
              _hasError = false;
            });
            _controller!.setLooping(true);
            _controller!.setVolume(0);
            _controller!.pause();
          })
          .catchError((Object _) {
            if (!mounted) return;
            setState(() => _hasError = true);
          });
    setState(() {});
  }

  void _disarm() {
    _controller?.dispose();
    _controller = null;
    _armed = false;
    _initialized = false;
    _hasError = false;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: widget.placeholderColor ?? AppColors.mediaSurface,
      child: const Center(
        child: Icon(Icons.play_circle_outline, color: Colors.white54, size: 40),
      ),
    );

    final aspect = _initialized ? _controller!.value.aspectRatio : 16 / 9;

    final content = !_armed || !_initialized || _hasError
        ? placeholder
        : FittedBox(
            fit: widget.fit,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoSurface(controller: _controller!),
            ),
          );

    return VisibilityDetector(
      key: ValueKey('video-thumb-${widget.videoUrl}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: AspectRatio(aspectRatio: aspect, child: content),
    );
  }
}
