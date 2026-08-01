import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:keek_news/model/failures.dart';

abstract class BaseUseCase {
  const BaseUseCase();

  Future<Either<Failure, T>> guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } catch (e, st) {
      debugPrint('UseCase guard caught: $e\n$st');
      return Left(_toFailure(e));
    }
  }

  Future<Either<Failure, Unit>> guardUnit(
    Future<void> Function() action,
  ) async {
    try {
      await action();
      return const Right(unit);
    } catch (e, st) {
      debugPrint('UseCase guardUnit caught: $e\n$st');
      return Left(_toFailure(e));
    }
  }

  Failure _toFailure(Object error) {
    if (error is Failure) return error;
    return ServerFailure(error.toString());
  }
}
