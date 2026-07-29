import 'package:dartz/dartz.dart';
import 'package:happy_news/core/errors/failures.dart';
import 'package:happy_news/data/datasources/github_remote_ds.dart';
import 'package:happy_news/data/parsers/github_release_parser.dart';
import 'package:happy_news/domain/entities/app_release.dart';
import 'package:happy_news/domain/repositories/update_repository.dart';

class UpdateRepositoryImpl implements UpdateRepository {
  const UpdateRepositoryImpl({required this.remoteDs});
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
