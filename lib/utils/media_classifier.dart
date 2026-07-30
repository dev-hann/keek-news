enum MediaType { image, video, audio, youtube, link, unknown }

abstract final class MediaClassifier {
  static const _imageExts = {
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.bmp',
    '.svg',
  };
  static const _videoExts = {'.mp4', '.webm', '.avi', '.mov', '.mkv'};
  static const _audioExts = {'.mp3', '.wav', '.ogg'};

  static const _loadableImageExts = {
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.bmp',
  };

  static MediaType classify(String url) {
    if (url.isEmpty) return MediaType.unknown;

    final unwrapped = unwrapDownloadPhp(url) ?? url;
    final lower = unwrapped.toLowerCase();

    if (extractYoutubeId(unwrapped) != null) return MediaType.youtube;

    for (final ext in _videoExts) {
      if (lower.endsWith(ext)) return MediaType.video;
    }
    for (final ext in _imageExts) {
      if (lower.endsWith(ext)) return MediaType.image;
    }
    for (final ext in _audioExts) {
      if (lower.endsWith(ext)) return MediaType.audio;
    }

    if (lower.contains('thumb.php') || lower.contains('image_view')) {
      return MediaType.image;
    }

    if (unwrapped.startsWith('http')) return MediaType.link;

    return MediaType.unknown;
  }

  static String? unwrapDownloadPhp(String url) {
    final match = RegExp(
      r'download\.php\?url=(https?://[^&]+)',
    ).firstMatch(url);
    return match?.group(1);
  }

  static String? extractYoutubeId(String url) {
    final patterns = [
      RegExp(r'(?:youtube\.com/watch\?v=|youtu\.be/)([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]{11})'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null) return match.group(1);
    }
    return null;
  }

  static bool isMedia(String url) {
    final t = classify(url);
    return t == MediaType.image ||
        t == MediaType.video ||
        t == MediaType.audio ||
        t == MediaType.youtube;
  }

  static bool isLoadableImage(String url) {
    if (url.isEmpty) return false;

    if (url.contains('url_enc=')) return false;

    final lower = url.toLowerCase();
    final queryIdx = lower.indexOf('?');
    final path = queryIdx >= 0 ? lower.substring(0, queryIdx) : lower;

    if (lower.contains('thumb.php?url=')) return true;

    for (final ext in _loadableImageExts) {
      if (path.endsWith(ext)) return true;
    }
    return false;
  }
}
