import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable implements Exception {
  const Failure(this.message, {this.http});

  final String message;
  final HttpDiagnostics? http;

  @override
  List<Object?> get props => [message, http];

  @override
  String toString() => '$runtimeType($message)';
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.http});
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.http});
}

class ParseFailure extends Failure {
  const ParseFailure(super.message, {super.http});
}

class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.http});
}

class UpdateFailure extends Failure {
  const UpdateFailure(super.message, {super.http});
}

class HttpDiagnostics extends Equatable {
  const HttpDiagnostics({
    this.statusCode,
    this.headers = const {},
    this.bodySnippet = '',
    this.requestPath,
  });

  final int? statusCode;
  final Map<String, String> headers;
  final String bodySnippet;
  final String? requestPath;

  @override
  List<Object?> get props => [statusCode, headers, bodySnippet, requestPath];
}
