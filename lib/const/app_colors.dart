import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color imageViewerBackground = Colors.black;
  static const Color imageViewerOverlay = Colors.black54;
  static const Color imageViewerForeground = Colors.white;
  static const Color imageViewerForegroundMuted = Colors.white54;

  /// Solid black used as the surface behind videos and image overlays where
  /// letterboxing is desired (letterboxed media reads as black to the eye).
  static const Color mediaSurface = Colors.black;

  /// Muted placeholder background shown behind unloaded media in the feed.
  /// Always light grey regardless of theme so the placeholder is visible in
  /// both light and dark mode (matches typical image-loading UX).
  static const Color imagePlaceholder = Color(0xFFE0E0E0);

  static const Color _recTierLow = Color(0xFF9E9E9E);
  static const Color _recTierMid = Color(0xFFFF6D00);
  static const Color _recTierHigh = Color(0xFF43A047);
  static const Color _recTierHot = Color(0xFFE53935);

  static Color recommendColor(int count, ColorScheme _) {
    if (count >= 100) return _recTierHot;
    if (count >= 50) return _recTierHigh;
    if (count >= 10) return _recTierMid;
    return _recTierLow;
  }

  static FontWeight recommendWeight(int count) {
    if (count >= 100) return FontWeight.w700;
    if (count >= 50) return FontWeight.w600;
    return FontWeight.w500;
  }
}
