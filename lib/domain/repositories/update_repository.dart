import 'package:dartz/dartz.dart';
import 'package:happy_news/core/errors/failures.dart';
import 'package:happy_news/domain/entities/app_release.dart';

abstract class UpdateRepository {
  Future<Either<Failure, AppRelease>> getLatestRelease();
}
