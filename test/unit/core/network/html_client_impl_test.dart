import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/network/html_client_impl.dart';

void main() {
  group('HtmlClientImpl', () {
    test('should throw DioException when dio fails with bad URL', () {
      final client = HtmlClientImpl(
        dio: Dio(
          BaseOptions(
            baseUrl: 'http://invalid.host.that.does.not.exist.example',
            responseType: ResponseType.bytes,
          ),
        ),
      );

      expect(() => client.get('/test.html'), throwsA(isA<DioException>()));
    });

    test('should construct with default dio config', () {
      final client = HtmlClientImpl();

      expect(client, isNotNull);
    });
  });
}
