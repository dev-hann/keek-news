import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:keek_news/model/app_release.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/repository/update/update_repo.dart';
import 'package:keek_news/service/github_remote_service.dart';

class UpdateImpl implements UpdateRepo {
  const UpdateImpl({required this.remoteDs});
  final GitHubRemoteService remoteDs;

  @override
  Future<Either<Failure, AppRelease>> getLatestRelease() async {
    try {
      final json = await remoteDs.fetchLatestRelease();
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) {
        return const Left(UpdateFailure('Invalid release JSON'));
      }
      final release = AppRelease.fromJson(decoded);
      if (release.version.isEmpty || release.htmlUrl.isEmpty) {
        return const Left(UpdateFailure('Failed to parse release info'));
      }
      return Right(release);
    } catch (e) {
      return Left(UpdateFailure(e.toString()));
    }
  }
}
