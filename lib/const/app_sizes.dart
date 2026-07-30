abstract final class AppSizes {
  static const double minTouchTarget = 44;

  static const double thumbnailSmall = 48;
  static const double thumbnailMedium = 72;
  static const double thumbnailLarge = 120;

  static const double screenHPadding = 16;

  static const double iconSmall = 12;
  static const double iconMedium = 16;
  static const double iconLarge = 24;

  static const double avatarSmall = 32;
  static const double avatarMedium = 40;
  static const double avatarLarge = 56;

  static const double chipHeight = 32;
  static const double dividerHeight = 24;
  static const double badgeMinSize = 20;

  static const double imagePlaceholderHeight = 200;
  static const double imageViewerIndicatorBottom = 32;
  static const double imageViewerIndicatorHeight = 32;

  static const double feedMediaHeightRatio = 0.66;
  static const double feedMediaMinHeight = 420;
  static const double feedMediaMaxHeight = 600;

  static double feedMediaHeight(double screenHeight) {
    final h = screenHeight * feedMediaHeightRatio;
    if (h < feedMediaMinHeight) return feedMediaMinHeight;
    if (h > feedMediaMaxHeight) return feedMediaMaxHeight;
    return h;
  }
}
