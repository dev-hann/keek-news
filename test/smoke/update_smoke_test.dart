import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/app_release.dart';
import 'package:keek_news/service/dio_github_remote_service.dart';

void main() {
  final skip = Platform.environment['SMOKE'] != '1';

  group('Smoke: GitHub releases API with live server', () {
    test('should fetch and parse the latest release from GitHub', () async {
      final remoteDs = DioGitHubRemoteService();
      final json = await remoteDs.fetchLatestRelease();

      expect(json, isNotEmpty, reason: 'GitHub API should return JSON');

      final decoded = jsonDecode(json);
      expect(decoded, isA<Map<String, dynamic>>());
      final release = AppRelease.fromJson(decoded as Map<String, dynamic>);
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
      final remoteDs = DioGitHubRemoteService();
      final json = await remoteDs.fetchLatestRelease();

      expect(
        json,
        contains('"tag_name"'),
        reason: 'GitHub response must contain tag_name field',
      );
    }, skip: skip);
  });
}
