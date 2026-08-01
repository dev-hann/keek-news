import 'dart:convert';

import 'package:keek_news/model/app_release.dart';
import 'package:keek_news/repository/update/update_repo.dart';
import 'package:keek_news/service/github_remote_service.dart';

class UpdateImpl implements UpdateRepo {
  const UpdateImpl({required this.remoteDs});
  final GitHubRemoteService remoteDs;

  @override
  Future<AppRelease> getLatestRelease() async {
    final json = await remoteDs.fetchLatestRelease();
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid release JSON');
    }
    final release = AppRelease.fromJson(decoded);
    if (release.version.isEmpty || release.htmlUrl.isEmpty) {
      throw const FormatException('Failed to parse release info');
    }
    return release;
  }
}
