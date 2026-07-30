import 'package:dartz/dartz.dart';
import 'package:keek_news/model/app_release.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/repository/update/update_repo.dart';
import 'package:keek_news/service/github_remote_ds.dart';
import 'package:keek_news/service/parser/github_release_parser.dart';

class UpdateImpl implements UpdateRepo {
  const UpdateImpl({required this.remoteDs});
  final GitHubRemoteDs remoteDs;

  @override
  Future<Either<Failure, AppRelease>> getLatestRelease() async {
    try {
      final json = await remoteDs.fetchLatestRelease();
      final dto = GitHubReleaseParser.parse(json);

      if (dto == null) {
        return const Left(UpdateFailure('Failed to parse release info'));
      }

      return Right(dto.toEntity());
    } catch (e) {
      return Left(UpdateFailure(e.toString()));
    }
  }
}
