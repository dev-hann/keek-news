import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/failures.dart';

T unwrapRight<T>(Either<Failure, T> either) =>
    either.fold((f) => throw TestFailure('Expected Right, got Left($f)'), id);
