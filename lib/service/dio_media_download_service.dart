import 'dart:io';

import 'package:dio/dio.dart';
import 'package:keek_news/model/download_progress.dart';
import 'package:keek_news/service/community_headers.dart';
import 'package:keek_news/service/media_download_service.dart';
import 'package:path_provider/path_provider.dart';

final RegExp _urlExtensionPattern = RegExp(r'\.([a-zA-Z0-9]{2,5})$');

class DioMediaDownloadService implements MediaDownloadService {
  DioMediaDownloadService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              responseType: ResponseType.bytes,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(minutes: 5),
            ),
          );

  final Dio _dio;

  @override
  Future<String> download(
    String url, {
    String fallbackExtension = '',
    void Function(DownloadProgress progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await getTemporaryDirectory();
    final fileName =
        'media_${DateTime.now().microsecondsSinceEpoch}'
        '${_extensionFor(url, fallbackExtension)}';
    final savePath = '${dir.path}/$fileName';

    try {
      await _dio.download(
        url,
        savePath,
        cancelToken: cancelToken,
        options: Options(headers: mediaDownloadHeaders(url)),
        onReceiveProgress: (received, total) {
          onProgress?.call(
            DownloadProgress(receivedBytes: received, totalBytes: total),
          );
        },
      );
      return savePath;
    } on DioException catch (e) {
      try {
        final partial = File(savePath);
        if (partial.existsSync()) await partial.delete();
      } catch (_) {
        // Best-effort cleanup of the partial file; the download failure is
        // the error worth reporting.
      }
      throw MediaDownloadException(
        canceled: e.type == DioExceptionType.cancel,
        detail: e.message,
      );
    }
  }

  /// gal infers the media type from the file extension, so a URL without one
  /// (e.g. CDN urls ending in a query string) must fall back to the
  /// caller-provided kind-specific default.
  String _extensionFor(String url, String fallback) {
    final path = Uri.tryParse(url)?.path ?? '';
    final match = _urlExtensionPattern.firstMatch(path);
    if (match != null) return '.${match.group(1)!.toLowerCase()}';
    return fallback.isEmpty ? '.bin' : fallback;
  }
}
