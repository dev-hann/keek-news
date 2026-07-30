class LongImage {
  const LongImage._();

  /// Returns the multiplier to apply to `PhotoViewComputedScale.contained` so
  /// the image fills the viewport width (fit-width), enabling vertical reading
  /// of long images; or `null` when the image is not long (use plain contained).
  ///
  /// Aspects are width/height. An image is "long" when, at fit-width, its
  /// displayed height exceeds the viewport height, i.e. [imageAspect] <
  /// [viewportAspect].
  static double? fitWidthScale({
    required double imageAspect,
    required double viewportAspect,
  }) {
    if (imageAspect < viewportAspect) {
      return viewportAspect / imageAspect;
    }
    return null;
  }
}
