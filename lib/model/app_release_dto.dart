import 'package:equatable/equatable.dart';
import 'package:keek_news/model/app_release.dart';

class AppReleaseDto extends Equatable {
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

  @override
  List<Object?> get props => [version, htmlUrl, downloadUrl, releaseNotes];
}
