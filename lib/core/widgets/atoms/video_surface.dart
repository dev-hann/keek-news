import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoSurface extends StatelessWidget {
  const VideoSurface({required this.controller, super.key});
  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      child: SizedBox(
        width: controller.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}
