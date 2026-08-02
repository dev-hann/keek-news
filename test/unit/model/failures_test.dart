import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/failures.dart';

void main() {
  group('ServerFailure', () {
    test('should store message', () {
      const failure = ServerFailure('HTTP 500');

      expect(failure.message, 'HTTP 500');
    });

    test('should support value equality when message matches', () {
      const a = ServerFailure('err');
      const b = ServerFailure('err');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('should not be equal when message differs', () {
      const a = ServerFailure('err1');
      const b = ServerFailure('err2');

      expect(a, isNot(equals(b)));
    });
  });

  group('NetworkFailure', () {
    test('should store message', () {
      const failure = NetworkFailure('No connection');

      expect(failure.message, 'No connection');
    });

    test('should support value equality', () {
      const a = NetworkFailure('err');
      const b = NetworkFailure('err');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('should not be equal to ServerFailure', () {
      const a = NetworkFailure('err');
      const b = ServerFailure('err');

      expect(a, isNot(equals(b)));
    });
  });

  group('ParseFailure', () {
    test('should store message', () {
      const failure = ParseFailure('Invalid HTML');

      expect(failure.message, 'Invalid HTML');
    });

    test('should support value equality', () {
      const a = ParseFailure('err');
      const b = ParseFailure('err');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('should not be equal to other failure types', () {
      const a = ParseFailure('err');
      const b = ServerFailure('err');
      const c = NetworkFailure('err');

      expect(a, isNot(equals(b)));
      expect(a, isNot(equals(c)));
    });
  });

  group('AuthFailure', () {
    test('should store message', () {
      const failure = AuthFailure('Login required');

      expect(failure.message, 'Login required');
    });

    test('should support value equality', () {
      const a = AuthFailure('err');
      const b = AuthFailure('err');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('should not be equal to other failure types', () {
      const a = AuthFailure('err');

      expect(a, isNot(equals(const ServerFailure('err'))));
      expect(a, isNot(equals(const NetworkFailure('err'))));
      expect(a, isNot(equals(const ParseFailure('err'))));
    });
  });

  group('UpdateFailure', () {
    test('should store message', () {
      const failure = UpdateFailure('GitHub API rate limit');

      expect(failure.message, 'GitHub API rate limit');
    });

    test('should support value equality', () {
      const a = UpdateFailure('err');
      const b = UpdateFailure('err');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('should not be equal to other failure types', () {
      const a = UpdateFailure('err');

      expect(a, isNot(equals(const ServerFailure('err'))));
      expect(a, isNot(equals(const NetworkFailure('err'))));
      expect(a, isNot(equals(const ParseFailure('err'))));
      expect(a, isNot(equals(const AuthFailure('err'))));
    });
  });

  group('Failure cross-type', () {
    test(
      'all five types with same message should not be equal to each other',
      () {
        const server = ServerFailure('x');
        const network = NetworkFailure('x');
        const parse = ParseFailure('x');
        const auth = AuthFailure('x');
        const update = UpdateFailure('x');

        expect({server, network, parse, auth, update}, hasLength(5));
      },
    );
  });

  group('HttpDiagnostics', () {
    test('defaults to empty values', () {
      const diag = HttpDiagnostics();

      expect(diag.statusCode, isNull);
      expect(diag.headers, isEmpty);
      expect(diag.bodySnippet, '');
      expect(diag.requestPath, isNull);
    });

    test('supports value equality', () {
      const a = HttpDiagnostics(
        statusCode: 503,
        headers: {'server': 'cloudflare'},
        bodySnippet: 'body',
        requestPath: '/716882815',
      );
      const b = HttpDiagnostics(
        statusCode: 503,
        headers: {'server': 'cloudflare'},
        bodySnippet: 'body',
        requestPath: '/716882815',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when statusCode differs', () {
      const a = HttpDiagnostics(statusCode: 503);
      const b = HttpDiagnostics(statusCode: 500);

      expect(a, isNot(equals(b)));
    });

    test('not equal when headers differ', () {
      const a = HttpDiagnostics(headers: {'server': 'cloudflare'});
      const b = HttpDiagnostics(headers: {'server': 'nginx'});

      expect(a, isNot(equals(b)));
    });
  });

  group('Failure.http field', () {
    test('defaults to null when not provided', () {
      const failure = ServerFailure('msg');

      expect(failure.http, isNull);
    });

    test('carries HttpDiagnostics when provided', () {
      const diag = HttpDiagnostics(statusCode: 503);
      const failure = ServerFailure('msg', http: diag);

      expect(failure.http, isNotNull);
      expect(failure.http!.statusCode, 503);
    });

    test('equal when both http null', () {
      const a = ServerFailure('msg');
      const b = ServerFailure('msg');

      expect(a, equals(b));
    });

    test('not equal when http differs', () {
      const a = ServerFailure('msg', http: HttpDiagnostics(statusCode: 503));
      const b = ServerFailure('msg', http: HttpDiagnostics(statusCode: 500));

      expect(a, isNot(equals(b)));
    });

    test('not equal when one has http and other does not', () {
      const a = ServerFailure('msg', http: HttpDiagnostics(statusCode: 503));
      const b = ServerFailure('msg');

      expect(a, isNot(equals(b)));
    });
  });
}
