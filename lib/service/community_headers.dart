/// Browser-impersonation headers shared by page fetches (service_locator) and
/// media downloads.
const String mobileUserAgent =
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/138.0.0.0 Mobile Safari/537.36';

const String desktopUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36';

const Map<String, String> browserHeaders = <String, String>{
  'Accept':
      'text/html,application/xhtml+xml,application/xml;q=0.9,'
      'image/avif,image/webp,*/*;q=0.8',
  'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
  'Sec-Fetch-Dest': 'document',
  'Sec-Fetch-Mode': 'navigate',
  'Sec-Fetch-Site': 'same-origin',
  'Sec-Fetch-User': '?1',
  'Upgrade-Insecure-Requests': '1',
};

class _CommunityProfile {
  const _CommunityProfile({required this.ua, required this.referer});

  final String ua;
  final String referer;
}

/// Host-suffix → per-community UA/Referer, mirroring the page-fetch profiles
/// in service_locator. Some community CDNs (dogdrip, fmkorea) reject
/// headerless media requests, so downloads must reuse the same identity.
const Map<String, _CommunityProfile> _profilesByHostSuffix = {
  'humoruniv.com': _CommunityProfile(
    ua: mobileUserAgent,
    referer: 'https://m.humoruniv.com/board/pds/',
  ),
  'todayhumor.co.kr': _CommunityProfile(
    ua: desktopUserAgent,
    referer: 'https://www.todayhumor.co.kr/board/humorbest.php',
  ),
  'ppomppu.co.kr': _CommunityProfile(
    ua: desktopUserAgent,
    referer: 'https://www.ppomppu.co.kr/zboard/zboard.php?id=humor',
  ),
  'dogdrip.net': _CommunityProfile(
    ua: desktopUserAgent,
    referer: 'https://www.dogdrip.net/index.php?mid=dogdrip',
  ),
  'fmkorea.com': _CommunityProfile(
    ua: desktopUserAgent,
    referer: 'https://www.fmkorea.com/index.php?mid=humor',
  ),
  'bobaedream.co.kr': _CommunityProfile(
    ua: desktopUserAgent,
    referer: 'https://www.bobaedream.co.kr/list?code=humor',
  ),
  'ruliweb.com': _CommunityProfile(
    ua: desktopUserAgent,
    referer: 'https://bbs.ruliweb.com/best/humor',
  ),
  'nate.com': _CommunityProfile(
    ua: desktopUserAgent,
    referer: 'https://pann.nate.com/talk',
  ),
};

/// Headers a media download should send for [url]. Falls back to the desktop
/// UA with no Referer for unknown hosts (most CDNs don't check).
Map<String, String> mediaDownloadHeaders(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  if (host.isEmpty) return {'User-Agent': desktopUserAgent};
  for (final entry in _profilesByHostSuffix.entries) {
    if (host.endsWith(entry.key)) {
      return {
        'User-Agent': entry.value.ua,
        'Referer': entry.value.referer,
        ...browserHeaders,
      };
    }
  }
  return {'User-Agent': desktopUserAgent, ...browserHeaders};
}
