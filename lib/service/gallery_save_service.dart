/// Thrown by [GallerySaveService] implementations when saving to the device
/// gallery fails, so the repository can map the cause to a typed failure.
class GallerySaveException implements Exception {
  const GallerySaveException({required this.permissionDenied});

  /// True when the failure was an access denial rather than a generic error.
  final bool permissionDenied;

  @override
  String toString() =>
      'GallerySaveException(permissionDenied: '
      '$permissionDenied)';
}

abstract class GallerySaveService {
  /// Saves the image file at [path] into the device gallery.
  ///
  /// Throws [GallerySaveException] on failure. [path] must include a
  /// file extension so the gallery saver can infer the media type.
  Future<void> putImage(String path);

  /// Saves the video file at [path] into the device gallery.
  Future<void> putVideo(String path);
}
