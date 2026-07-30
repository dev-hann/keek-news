/// Reports and clears the on-disk image cache (used by `CachedNetworkImage`
/// via `flutter_cache_manager`'s `DefaultCacheManager`).
abstract class ImageCacheService {
  /// Total size in bytes of all cached image files on disk.
  Future<int> getSizeBytes();

  /// Removes all cached image files from disk.
  Future<void> clear();
}
