import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable implements Exception {
  const Failure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];

  @override
  String toString() => '$runtimeType($message)';
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class ParseFailure extends Failure {
  const ParseFailure(super.message);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class UpdateFailure extends Failure {
  const UpdateFailure(super.message);
}
