abstract final class UrlNormalizer {
  static String normalize(String url) {
    if (url.isEmpty) return url;

    var normalized = url.trim();

    if (normalized.startsWith('//')) {
      normalized = 'https:$normalized';
    }

    while (normalized.contains(':///')) {
      normalized = normalized.replaceFirst(':///', '://');
    }

    normalized = normalized.replaceAllMapped(RegExp('(?<!:)/{2,}'), (m) => '/');

    return normalized;
  }
}
