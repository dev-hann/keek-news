/**
 * Every community id the models know. Ids of communities the web app does not
 * serve yet stay here, so saved data that names them still types.
 */
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

export interface Community {
  id: CommunityId;
  shortName: string;
  displayName: string;
  /** Hex color of the community's brand. */
  brandColor: string;
  baseUrl: string;
}

/**
 * The communities the web app serves. Adding one takes two entries that the
 * compiler keeps in step: its id here, with its metadata below, and its
 * repository in `service_locator.ts`.
 */
export const registeredCommunityIds = ['humoruniv'] as const satisfies readonly CommunityId[];

export type RegisteredCommunityId = (typeof registeredCommunityIds)[number];

export const communities: Record<RegisteredCommunityId, Community> = {
  humoruniv: {
    id: 'humoruniv',
    shortName: '웃대',
    displayName: '웃긴대학',
    brandColor: '#EF4444',
    baseUrl: 'https://m.humoruniv.com',
  },
};

export const registeredCommunities: readonly Community[] = registeredCommunityIds.map(
  (id) => communities[id]
);

/** The metadata of a community the web app serves, or undefined for any other id. */
export function findCommunity(id: CommunityId): Community | undefined {
  return registeredCommunityIds.includes(id as RegisteredCommunityId)
    ? communities[id as RegisteredCommunityId]
    : undefined;
}

/**
 * Where each community's pages live, served or not, so a link of any community
 * still resolves. A community the app serves takes its address from its
 * metadata above, so the two cannot disagree.
 */
export const communityBaseUrls: Record<CommunityId, string> = {
  humoruniv: communities.humoruniv.baseUrl,
  todayhumor: 'https://www.todayhumor.co.kr',
  dogdrip: 'https://www.dogdrip.net',
  ppomppu: 'https://www.ppomppu.co.kr',
  fmkorea: 'https://www.fmkorea.com',
  bobaedream: 'https://www.bobaedream.co.kr',
  ruliweb: 'https://bbs.ruliweb.com',
  natepann: 'https://pann.nate.com',
};
