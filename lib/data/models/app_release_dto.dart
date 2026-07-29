import 'package:happy_news/domain/entities/app_release.dart';

class AppReleaseDto {
  const AppReleaseDto({
    required this.version,
    required this.htmlUrl,
    this.downloadUrl,
    this.releaseNotes,
  });
  final String version;
  final String htmlUrl;
  final String? downloadUrl;
  final String? releaseNotes;

  AppRelease toEntity() => AppRelease(
    version: version,
    htmlUrl: htmlUrl,
    downloadUrl: downloadUrl,
    releaseNotes: releaseNotes,
  );
}
