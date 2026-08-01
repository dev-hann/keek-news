import 'package:keek_news/model/community.dart';

abstract final class UrlBuilder {
  static String resolveAbsolute(
    CommunityId community,
    String relativeOrAbsolute,
  ) {
    if (relativeOrAbsolute.startsWith('http://') ||
        relativeOrAbsolute.startsWith('https://')) {
      return relativeOrAbsolute;
    }
    final base = Community.findById(community)?.baseUrl;
    if (base == null) return relativeOrAbsolute;
    return Uri.parse(base).resolve(relativeOrAbsolute).toString();
  }
}
