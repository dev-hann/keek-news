abstract class ImageCacheRepo {
  Future<int> getSizeBytes();

  Future<void> clear();
}
