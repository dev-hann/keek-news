import 'package:flutter/material.dart';

/// Centered buffering spinner shown over a video surface while the underlying
/// video controller reports its buffering state.
///
/// Renders nothing when [visible] is false, and is wrapped in [IgnorePointer]
/// so taps fall through to the controls beneath it.
class VideoBufferingOverlay extends StatelessWidget {
  const VideoBufferingOverlay({required this.visible, super.key});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return const IgnorePointer(
      child: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}
