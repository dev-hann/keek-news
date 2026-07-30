import 'package:dartz/dartz.dart';
import 'package:keek_news/model/app_release.dart';
import 'package:keek_news/model/failures.dart';

abstract class UpdateRepo {
  Future<Either<Failure, AppRelease>> getLatestRelease();
}
