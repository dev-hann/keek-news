import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/service/dio_html_service.dart';

DioHtmlService _newClient({Dio? dio}) => DioHtmlService(
  dio: dio ?? Dio(BaseOptions(baseUrl: 'https://example.test')),
  encoding: 'utf-8',
);

void main() {
  group('DioHtmlService', () {
    test('should throw NetworkFailure when dio fails with bad URL', () {
      final client = _newClient(
        dio: Dio(
          BaseOptions(
            baseUrl: 'http://invalid.host.that.does.not.exist.example',
            responseType: ResponseType.bytes,
          ),
        ),
      );

      expect(() => client.get('/test.html'), throwsA(isA<NetworkFailure>()));
    });

    test('should construct with provided dio config', () {
      final client = _newClient();

      expect(client, isNotNull);
    });

    group('extractNumber', () {
      final client = _newClient();

      test('returns 0 for null', () {
        expect(client.extractNumber(null), 0);
      });

      test('returns 0 for empty string', () {
        expect(client.extractNumber(''), 0);
      });

      test('strips non-digit characters', () {
        expect(client.extractNumber('1,234'), 1234);
        expect(client.extractNumber('조회 5,678회'), 5678);
        expect(client.extractNumber('[42]'), 42);
      });

      test('returns 0 when no digits present', () {
        expect(client.extractNumber('abc'), 0);
      });
    });

    group('textOf', () {
      final client = _newClient();

      test('returns empty string for null', () {
        expect(client.textOf(null), '');
      });

      test('returns trimmed text of element', () {
        final el = Element.html('<span>  hello  </span>');
        expect(client.textOf(el), 'hello');
      });
    });

    group('attrOf', () {
      final client = _newClient();

      test('returns null for null element', () {
        expect(client.attrOf(null, 'href'), isNull);
      });

      test('returns attribute value', () {
        final el = Element.html('<a href="/list">list</a>');
        expect(client.attrOf(el, 'href'), '/list');
      });

      test('returns null when attribute missing', () {
        final el = Element.html('<a>no href</a>');
        expect(client.attrOf(el, 'href'), isNull);
      });
    });

    group('statOf', () {
      final client = _newClient();

      test('returns 0 for null parent', () {
        expect(client.statOf(null, '.num'), 0);
      });

      test('extracts number from child element', () {
        final parent = Element.html(
          '<div><span class="num">1,234</span></div>',
        );
        expect(client.statOf(parent, '.num'), 1234);
      });

      test('returns 0 when selector not found', () {
        final parent = Element.html('<div>nothing</div>');
        expect(client.statOf(parent, '.num'), 0);
      });
    });
  });
}
