import 'package:meta/meta.dart';

enum CommunityId { humoruniv, todayhumor, dogdrip, ppomppu }

@immutable
class Community {
  const Community({
    required this.id,
    required this.shortName,
    required this.displayName,
    required this.brandColorArgb,
    required this.iconAsset,
  });
  final CommunityId id;
  final String shortName;
  final String displayName;
  final int brandColorArgb;
  final String iconAsset;

  static Community? findById(CommunityId id) {
    for (final c in communities) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Community && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

const communities = <Community>[
  Community(
    id: CommunityId.humoruniv,
    shortName: '웃대',
    displayName: '웃긴대학',
    brandColorArgb: 0xFFE5413B,
    iconAsset: 'assets/icons/community_humoruniv.png',
  ),
  Community(
    id: CommunityId.todayhumor,
    shortName: '오유',
    displayName: '오늘의유머',
    brandColorArgb: 0xFF2E8B57,
    iconAsset: 'assets/icons/community_todayhumor.png',
  ),
  Community(
    id: CommunityId.dogdrip,
    shortName: '개드립',
    displayName: 'DogDrip',
    brandColorArgb: 0xFF1A1A2E,
    iconAsset: 'assets/icons/community_dogdrip.png',
  ),
  Community(
    id: CommunityId.ppomppu,
    shortName: '뽐뿌',
    displayName: '뽐뿌',
    brandColorArgb: 0xFFFF6B00,
    iconAsset: 'assets/icons/community_ppomppu.png',
  ),
];
