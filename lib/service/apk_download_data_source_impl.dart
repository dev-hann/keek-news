import 'dart:io';

import 'package:dio/dio.dart';
import 'package:keek_news/service/apk_download_data_source.dart';

class ApkDownloadDataSourceImpl implements ApkDownloadDataSource {
  ApkDownloadDataSourceImpl({
    required Dio dio,
    required ApkSavePathResolver resolveSavePath,
  }) : _dio = dio,
       _resolveSavePath = resolveSavePath;

  final Dio _dio;
  final ApkSavePathResolver _resolveSavePath;

  CancelToken? _cancelToken;
  @override
  String? savedPath;

  @override
  Future<String> download(
    String url,
    void Function(int receivedBytes, int totalBytes) onProgress,
  ) async {
    final savePath = await _resolveSavePath();
    savedPath = savePath;
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    await _dio.download(
      url,
      savePath,
      onReceiveProgress: onProgress,
      cancelToken: cancelToken,
    );

    return savePath;
  }

  @override
  void cancel() {
    _cancelToken?.cancel();
    _cancelToken = null;
    _deleteFile();
  }

  void _deleteFile() {
    final path = savedPath;
    if (path != null) {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
  }
}
