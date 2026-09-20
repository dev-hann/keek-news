abstract class MediaShareService {
  /// Opens the system share sheet with the file at [path].
  Future<void> shareFile(String path);

  /// Opens the system share sheet with [text].
  Future<void> shareText(String text);
}
