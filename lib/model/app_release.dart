import 'package:equatable/equatable.dart';

class AppRelease extends Equatable {
  const AppRelease({
    required this.version,
    required this.htmlUrl,
    this.downloadUrl,
    this.releaseNotes,
  });
  final String version;
  final String htmlUrl;
  final String? downloadUrl;
  final String? releaseNotes;

  @override
  List<Object?> get props => [version, htmlUrl, downloadUrl, releaseNotes];
}
