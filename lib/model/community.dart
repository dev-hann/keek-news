import 'package:equatable/equatable.dart';

enum CommunityId {
  humoruniv,
  todayhumor,
  dogdrip,
  ppomppu,
  fmkorea,
  bobaedream,
  ruliweb,
  natepann,
}

class Community extends Equatable {
  const Community({
    required this.id,
    required this.shortName,
    required this.displayName,
    required this.brandColorArgb,
    required this.iconAsset,
    required this.baseUrl,
  });
  final CommunityId id;
  final String shortName;
  final String displayName;
  final int brandColorArgb;
  final String iconAsset;
  final String baseUrl;

  static Community? findById(CommunityId id) {
    for (final c in communities) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  List<Object?> get props => [id];
}

// Communities that are compiled in (parser + metadata retained for the day
// they are re-enabled) but hidden from the UI and never fetched. Toggling a
// community out of this set restores it everywhere with no migration.
const hiddenCommunityIds = <CommunityId>{CommunityId.fmkorea};

final visibleCommunities = communities
    .where((c) => !hiddenCommunityIds.contains(c.id))
    .toList(growable: false);

const communities = <Community>[
  Community(
    id: CommunityId.humoruniv,
    shortName: '웃대',
    displayName: '웃긴대학',
    brandColorArgb: 0xFFEF4444,
    iconAsset: 'assets/icons/community_humoruniv.png',
    baseUrl: 'https://m.humoruniv.com',
  ),
  Community(
    id: CommunityId.todayhumor,
    shortName: '오유',
    displayName: '오늘의유머',
    brandColorArgb: 0xFF06B6A4,
    iconAsset: 'assets/icons/community_todayhumor.png',
    baseUrl: 'https://www.todayhumor.co.kr',
  ),
  Community(
    id: CommunityId.dogdrip,
    shortName: '개드립',
    displayName: 'DogDrip',
    brandColorArgb: 0xFFA855F7,
    iconAsset: 'assets/icons/community_dogdrip.png',
    baseUrl: 'https://www.dogdrip.net',
  ),
  Community(
    id: CommunityId.ppomppu,
    shortName: '뽐뿌',
    displayName: '뽐뿌',
    brandColorArgb: 0xFFF59E0B,
    iconAsset: 'assets/icons/community_ppomppu.png',
    baseUrl: 'https://www.ppomppu.co.kr',
  ),
  Community(
    id: CommunityId.fmkorea,
    shortName: 'FMK',
    displayName: 'FM코리아',
    brandColorArgb: 0xFF3B82F6,
    iconAsset: 'assets/icons/community_fmkorea.png',
    baseUrl: 'https://www.fmkorea.com',
  ),
  Community(
    id: CommunityId.bobaedream,
    shortName: '보배',
    displayName: '보배드림',
    brandColorArgb: 0xFF22C55E,
    iconAsset: 'assets/icons/community_bobaedream.png',
    baseUrl: 'https://www.bobaedream.co.kr',
  ),
  Community(
    id: CommunityId.ruliweb,
    shortName: '루리',
    displayName: '루리웹',
    brandColorArgb: 0xFFE11D48,
    iconAsset: 'assets/icons/community_ruliweb.png',
    baseUrl: 'https://bbs.ruliweb.com',
  ),
  Community(
    id: CommunityId.natepann,
    shortName: '네이트',
    displayName: '네이트판',
    brandColorArgb: 0xFFEA580C,
    iconAsset: 'assets/icons/community_natepann.png',
    baseUrl: 'https://pann.nate.com',
  ),
];
