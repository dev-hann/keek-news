import 'package:equatable/equatable.dart';

class AppRelease extends Equatable {
  const AppRelease({
    required this.version,
    required this.htmlUrl,
    this.downloadUrl,
    this.releaseNotes,
  });

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    final tagName = json['tag_name'] as String? ?? '';
    final version = _stripVPrefix(tagName);
    final htmlUrl = json['html_url'] as String? ?? '';
    final body = json['body'] as String? ?? '';

    String? downloadUrl;
    final assets = json['assets'] as List<dynamic>?;
    if (assets != null && assets.isNotEmpty) {
      for (final asset in assets.cast<Map<String, dynamic>>()) {
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          downloadUrl = asset['browser_download_url'] as String?;
          break;
        }
      }
    }

    return AppRelease(
      version: version,
      htmlUrl: htmlUrl,
      downloadUrl: downloadUrl,
      releaseNotes: body.isNotEmpty ? body : null,
    );
  }

  final String version;
  final String htmlUrl;
  final String? downloadUrl;
  final String? releaseNotes;

  static String _stripVPrefix(String tagName) {
    if (tagName.startsWith('v')) return tagName.substring(1);
    return tagName;
  }

  @override
  List<Object?> get props => [version, htmlUrl, downloadUrl, releaseNotes];
}
