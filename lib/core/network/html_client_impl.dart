import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';
import 'package:dio/dio.dart';
import 'package:humoruniv/core/network/html_client.dart';

class HtmlClientImpl implements HtmlClient {
  HtmlClientImpl({
    Dio? dio,
    String baseUrl = 'https://m.humoruniv.com',
    String encoding = 'euc-kr',
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
                      '(KHTML, like Gecko) Chrome/125.0.0.0 Mobile '
                      'Safari/537.36',
                },
                responseType: ResponseType.bytes,
              ),
            ),
        _encoding = encoding;

  final Dio _dio;
  final String _encoding;

  @override
  Future<String> get(String path) async {
    final response = await _dio.get<List<int>>(path);
    final bytes = response.data ?? <int>[];

    final decoded = await CharsetConverter.decode(
      _encoding,
      Uint8List.fromList(bytes),
    );
    return decoded;
  }
}
