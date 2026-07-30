import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/service/github_remote_ds_impl.dart';
import 'package:keek_news/service/parser/github_release_parser.dart';

void main() {
  final skip = Platform.environment['SMOKE'] != '1';

  group('Smoke: GitHub releases API with live server', () {
    test('should fetch and parse the latest release from GitHub', () async {
      final remoteDs = GitHubRemoteDsImpl();
      final json = await remoteDs.fetchLatestRelease();

      expect(json, isNotEmpty, reason: 'GitHub API should return JSON');

      final dto = GitHubReleaseParser.parse(json);
      expect(dto, isNotNull, reason: 'Latest release should be parseable');

      final release = dto!.toEntity();
      expect(
        release.version,
        isNotEmpty,
        reason: 'Version should not be empty',
      );
      expect(
        release.htmlUrl,
        startsWith('https://'),
        reason: 'html_url should be a valid URL',
      );
    }, skip: skip);

    test('should return JSON containing a version tag', () async {
      final remoteDs = GitHubRemoteDsImpl();
      final json = await remoteDs.fetchLatestRelease();

      expect(
        json,
        contains('"tag_name"'),
        reason: 'GitHub response must contain tag_name field',
      );
    }, skip: skip);
  });
}
