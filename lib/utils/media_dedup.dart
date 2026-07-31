abstract final class MediaDedup {
  /// Returns the filename portion of a media URL for deduplication.
  ///
  /// Two CDN mirrors of the same upload (e.g. `//cdn2.x/a/b/clip.mp4` and
  /// `https://img.x/a/b/clip.mp4`) share the same filename, so keying on it
  /// collapses them into one item.
  static String filenameKey(String url) {
    final noQuery = url.split('?').first;
    final slash = noQuery.lastIndexOf('/');
    final file = slash >= 0 ? noQuery.substring(slash + 1) : noQuery;
    return file.toLowerCase();
  }
}
