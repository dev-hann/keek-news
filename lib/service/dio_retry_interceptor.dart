import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Attempt counter is stashed on the request's `extra` map so it survives
/// across re-issued requests within the interceptor chain.
const _retryAttemptKey = 'retryInterceptor.attempt';

/// Retries transient failures (connection errors, timeouts, HTTP 503) with
/// backoff. Attached to every community Dio in configureDependencies.
///
/// Network errors (DNS flakes, connection drops) get a short fast schedule so
/// transient mobile-network hiccups recover quickly. HTTP 503 honors the
/// server's Retry-After header, capped at maxRetryAfter — a larger value
/// means the server is genuinely overloaded and we give up rather than hold.
///
/// Non-retriable failures (4xx other than 503, bad certificate, cancellation)
/// pass straight through. On exhaustion the original DioException is
/// forwarded to the next handler; DioHtmlService._toFailure maps it to a
/// typed Failure.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required Dio dio,
    this.networkBackoff = const [
      Duration(milliseconds: 500),
      Duration(seconds: 1),
      Duration(seconds: 2),
    ],
    this.serverBackoff = const [
      Duration(seconds: 1),
      Duration(seconds: 4),
      Duration(seconds: 10),
    ],
    this.maxRetryAfter = const Duration(seconds: 30),
  }) : _dio = dio;

  final Dio _dio;
  final List<Duration> networkBackoff;
  final List<Duration> serverBackoff;
  final Duration maxRetryAfter;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final attempt = (err.requestOptions.extra[_retryAttemptKey] as int?) ?? 0;
    final schedule = _scheduleFor(err);
    if (schedule == null || attempt >= schedule.length) {
      handler.next(err);
      return;
    }
    final delay = _resolveDelay(err, schedule[attempt]);
    if (delay == null) {
      // Server asked to wait longer than our cap → stop retrying.
      handler.next(err);
      return;
    }
    debugPrint(
      '[Retry] attempt ${attempt + 1}/${schedule.length} '
      'after ${delay.inMilliseconds}ms on ${err.type}',
    );
    await Future<void>.delayed(delay);
    err.requestOptions.extra[_retryAttemptKey] = attempt + 1;
    try {
      final response = await _dio.fetch<dynamic>(err.requestOptions);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  /// Picks the backoff schedule for retriable errors, or null if the error is
  /// not retriable.
  List<Duration>? _scheduleFor(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return networkBackoff;
      case DioExceptionType.badResponse:
        return err.response?.statusCode == 503 ? serverBackoff : null;
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return null;
    }
  }

  /// Returns the delay before the next attempt. For 503, honors `Retry-After`
  /// (capped at [maxRetryAfter]); returns null to give up when the server's
  /// ask exceeds the cap.
  Duration? _resolveDelay(DioException err, Duration scheduled) {
    if (err.type != DioExceptionType.badResponse) return scheduled;
    final retryAfterHeader = err.response?.headers.value('retry-after');
    if (retryAfterHeader == null) return scheduled;
    final seconds = int.tryParse(retryAfterHeader);
    if (seconds == null) return scheduled;
    final requested = Duration(seconds: seconds);
    if (requested > maxRetryAfter) return null;
    return requested;
  }
}
