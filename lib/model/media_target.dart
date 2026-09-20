import 'package:equatable/equatable.dart';
import 'package:keek_news/model/content_block.dart';

enum MediaKind { image, video, external }

/// A single media item the user long-pressed, resolved to the action the
/// sheet can offer.
///
/// [MediaKind.external] marks embeds hosted outside the community CDNs
/// (e.g. YouTube). They cannot be downloaded, only shared as a URL.
class MediaTarget extends Equatable {
  const MediaTarget({required this.url, required this.kind});

  factory MediaTarget.image(String url) =>
      MediaTarget(url: url, kind: MediaKind.image);

  factory MediaTarget.video(VideoBlock block) => MediaTarget(
    url: block.url,
    kind: _isExternalEmbed(block.url) ? MediaKind.external : MediaKind.video,
  );

  static bool _isExternalEmbed(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host.endsWith('youtube.com') ||
        host.endsWith('youtu.be') ||
        host.endsWith('vimeo.com');
  }

  final String url;
  final MediaKind kind;

  bool get isDownloadable => kind != MediaKind.external;

  @override
  List<Object?> get props => [url, kind];
}
