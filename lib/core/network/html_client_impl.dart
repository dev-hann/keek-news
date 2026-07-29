import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';
import 'package:dio/dio.dart';
import 'package:happy_news/core/network/html_client.dart';

const _mobileUA =
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/125.0.0.0 Mobile Safari/537.36';

const _desktopUA =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36';

class HtmlClientImpl implements HtmlClient {
  HtmlClientImpl({
    Dio? dio,
    String baseUrl = 'https://m.humoruniv.com',
    String encoding = 'euc-kr',
    bool desktop = false,
    this.cookieProvider,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               headers: {'User-Agent': desktop ? _desktopUA : _mobileUA},
               responseType: ResponseType.bytes,
             ),
           ),
       _encoding = encoding;

  final Dio _dio;
  final String _encoding;
  final String? Function()? cookieProvider;

  @override
  Future<String> get(String path) async {
    final headers = <String, dynamic>{};
    final cookie = cookieProvider?.call();
    if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
    }

    final response = await _dio.get<List<int>>(
      path,
      options: headers.isNotEmpty ? Options(headers: headers) : null,
    );
    final bytes = response.data ?? <int>[];

    final decoded = await CharsetConverter.decode(
      _encoding,
      Uint8List.fromList(bytes),
    );
    return decoded;
  }
}
