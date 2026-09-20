import 'package:dio/dio.dart';
import 'package:keek_news/model/download_progress.dart';

/// Thrown by [MediaDownloadService] implementations so the repository can map
/// the cause to a typed failure without depending on dio exceptions.
class MediaDownloadException implements Exception {
  const MediaDownloadException({required this.canceled, this.detail});

  /// True when the download was aborted through its cancel token rather than
  /// failing on the network.
  final bool canceled;
  final String? detail;

  @override
  String toString() =>
      'MediaDownloadException(${canceled ? 'canceled' : 'network'}'
      '${detail == null ? '' : ', $detail'})';
}

abstract class MediaDownloadService {
  /// Downloads [url] into a temp file and returns its absolute path.
  ///
  /// [fallbackExtension] (e.g. `.jpg`, `.mp4`) is used when the URL path has
  /// no usable extension — the gallery saver infers the media type from the
  /// file extension. Progress is reported through [onProgress]; cancellation
  /// through [cancelToken] throws a [MediaDownloadException] with
  /// `canceled: true`. Partial files are removed on any failure.
  Future<String> download(
    String url, {
    String fallbackExtension = '',
    void Function(DownloadProgress progress)? onProgress,
    CancelToken? cancelToken,
  });
}
