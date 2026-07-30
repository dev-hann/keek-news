/// Downloads the update APK to a local file with progress reporting.
abstract class ApkDownloadDataSource {
  /// Downloads [url] to a local file, invoking [onProgress] with
  /// (receivedBytes, totalBytes) as data arrives.
  ///
  /// Returns the absolute path of the downloaded file. Throws on failure.
  Future<String> download(
    String url,
    void Function(int receivedBytes, int totalBytes) onProgress,
  );

  /// Cancels an in-progress download (if any) and removes the partial file.
  void cancel();

  /// Returns the path of the last downloaded file, or null if none.
  String? get savedPath;
}

/// Resolves the absolute path where the update APK should be written.
/// Kept async so the platform directory lookup is deferred to download time
/// (not DI registration time), keeping unit tests that never download simple.
typedef ApkSavePathResolver = Future<String> Function();
