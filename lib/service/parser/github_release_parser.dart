import 'dart:convert';

import 'package:keek_news/model/app_release_dto.dart';

class GitHubReleaseParser {
  static AppReleaseDto? parse(String jsonString) {
    if (jsonString.trim().isEmpty) return null;

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;

      final tagName = json['tag_name'] as String? ?? '';
      final version = _stripVPrefix(tagName);
      if (version.isEmpty) return null;

      final htmlUrl = json['html_url'] as String? ?? '';
      if (htmlUrl.isEmpty) return null;

      final body = json['body'] as String? ?? '';

      String? downloadUrl;
      final assets = json['assets'] as List<dynamic>?;
      if (assets != null && assets.isNotEmpty) {
        for (final asset in assets) {
          final name = asset['name'] as String? ?? '';
          if (name.endsWith('.apk')) {
            downloadUrl = asset['browser_download_url'] as String?;
            break;
          }
        }
      }

      return AppReleaseDto(
        version: version,
        htmlUrl: htmlUrl,
        downloadUrl: downloadUrl,
        releaseNotes: body.isNotEmpty ? body : null,
      );
    } on FormatException {
      return null;
    }
  }

  static String _stripVPrefix(String tagName) {
    if (tagName.startsWith('v')) return tagName.substring(1);
    return tagName;
  }
}
