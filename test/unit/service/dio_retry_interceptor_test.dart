import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/service/dio_retry_interceptor.dart';

/// A scripted response (returned through the adapter; non-2xx becomes a
/// badResponse DioException in Dio's normal flow).
class _Resp {
  const _Resp({this.statusCode = 200, this.body = '', this.headers});
  final int statusCode;
  final String body;
  final Map<String, String>? headers;
}

/// A scripted thrown error (connectionError / timeout — no HTTP response).
class _Err {
  const _Err(this.type);
  final DioExceptionType type;
}

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._steps);
  final List<Object> _steps; // _Resp | _Err
  int _i = 0;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    final step = _steps[_i++];
    if (step is _Err) {
      throw DioException(
        requestOptions: options,
        type: step.type,
        message: 'err',
      );
    }
    final r = step as _Resp;
    final bytes = utf8.encode(r.body);
    return ResponseBody(
      Stream.value(Uint8List.fromList(bytes)),
      r.statusCode,
      headers: {
        Headers.contentLengthHeader: ['${bytes.length}'],
        for (final e in (r.headers ?? const {}).entries) e.key: [e.value],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Builds a Dio whose retry backoff is all `Duration.zero` (fast tests) unless
/// overridden. Returns the adapter so tests can assert call count.
({Dio dio, _ScriptedAdapter adapter}) _dio(
  List<Object> steps, {
  RetryInterceptor? interceptor,
  Duration maxRetryAfter = const Duration(seconds: 30),
}) {
  final adapter = _ScriptedAdapter(steps);
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://example.test',
      responseType: ResponseType.bytes,
    ),
  )..httpClientAdapter = adapter;
  dio.interceptors.add(
    interceptor ??
        RetryInterceptor(
          dio: dio,
          networkBackoff: const [Duration.zero, Duration.zero, Duration.zero],
          serverBackoff: const [Duration.zero, Duration.zero, Duration.zero],
          maxRetryAfter: maxRetryAfter,
        ),
  );
  return (dio: dio, adapter: adapter);
}

void main() {
  group('RetryInterceptor', () {
    test('retries 503 then succeeds', () async {
      final t = _dio([
        const _Resp(statusCode: 503),
        const _Resp(statusCode: 503),
        const _Resp(body: 'ok'),
      ]);

      await t.dio.get<List<int>>('/x');

      expect(t.adapter.calls, 3);
    });

    test('retries connectionError (DNS flake) then succeeds', () async {
      final t = _dio([
        const _Err(DioExceptionType.connectionError),
        const _Resp(body: 'ok'),
      ]);

      await t.dio.get<List<int>>('/x');

      expect(t.adapter.calls, 2);
    });

    test('retries connectionTimeout then succeeds', () async {
      final t = _dio([
        const _Err(DioExceptionType.connectionTimeout),
        const _Resp(body: 'ok'),
      ]);

      await t.dio.get<List<int>>('/x');

      expect(t.adapter.calls, 2);
    });

    test('does not retry non-503 client error (404)', () async {
      final t = _dio([const _Resp(statusCode: 404)]);

      await expectLater(
        t.dio.get<String>('/missing'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
      expect(t.adapter.calls, 1);
    });

    test('does not retry cancel', () async {
      final t = _dio([const _Err(DioExceptionType.cancel)]);

      await expectLater(t.dio.get<String>('/x'), throwsA(isA<DioException>()));
      expect(t.adapter.calls, 1);
    });

    test(
      'gives up after exhausting server backoff (3 retries → 4 attempts)',
      () async {
        final t = _dio([
          const _Resp(statusCode: 503),
          const _Resp(statusCode: 503),
          const _Resp(statusCode: 503),
          const _Resp(statusCode: 503),
        ]);

        await expectLater(
          t.dio.get<String>('/x'),
          throwsA(
            isA<DioException>().having(
              (e) => e.response?.statusCode,
              'statusCode',
              503,
            ),
          ),
        );
        expect(t.adapter.calls, 4);
      },
    );

    test('gives up after exhausting network backoff', () async {
      final t = _dio([
        const _Err(DioExceptionType.connectionError),
        const _Err(DioExceptionType.connectionError),
        const _Err(DioExceptionType.connectionError),
        const _Err(DioExceptionType.connectionError),
      ]);

      await expectLater(t.dio.get<String>('/x'), throwsA(isA<DioException>()));
      expect(t.adapter.calls, 4);
    });

    test('honors 503 Retry-After within cap (retries at header time)', () {
      fakeAsync((async) {
        final adapter = _ScriptedAdapter([
          const _Resp(statusCode: 503, headers: {'retry-after': '1'}),
          const _Resp(body: 'ok'),
        ]);
        final dio = Dio(
          BaseOptions(
            baseUrl: 'https://example.test',
            responseType: ResponseType.bytes,
          ),
        )..httpClientAdapter = adapter;
        dio.interceptors.add(
          RetryInterceptor(
            dio: dio,
            serverBackoff: const [Duration(seconds: 30)],
          ),
        );

        final done = Completer<void>();
        dio.get<List<int>>('/x').then((_) => done.complete());

        // Header says 1s — pump past it. If logic used serverBackoff (30s)
        // instead, retry wouldn't have fired within this window.
        async.elapse(const Duration(seconds: 2));
        expect(done.isCompleted, isTrue);
        expect(adapter.calls, 2);
      });
    });

    test('ignores Retry-After when above cap (gives up)', () {
      fakeAsync((async) {
        final adapter = _ScriptedAdapter([
          const _Resp(statusCode: 503, headers: {'retry-after': '120'}),
        ]);
        final dio = Dio(
          BaseOptions(
            baseUrl: 'https://example.test',
            responseType: ResponseType.bytes,
          ),
        )..httpClientAdapter = adapter;
        dio.interceptors.add(RetryInterceptor(dio: dio));

        Object? caught;
        dio
            .get<List<int>>('/x')
            .then(
              (_) {},
              onError: (Object e) {
                caught = e;
              },
            );

        async.elapse(const Duration(seconds: 200));
        expect(adapter.calls, 1);
        expect(caught, isA<DioException>());
      });
    });
  });
}
