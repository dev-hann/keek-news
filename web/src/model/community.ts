/** The communities the app reads, in the order the Flutter app lists them. */
export const communityIds = [
  'humoruniv',
  'todayhumor',
  'dogdrip',
  'ppomppu',
  'fmkorea',
  'bobaedream',
  'ruliweb',
  'natepann',
] as const;

export type CommunityId = (typeof communityIds)[number];
