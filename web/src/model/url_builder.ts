import { communityBaseUrls, type CommunityId } from './community';

/** The absolute address of a link of a community, from a path or an address. */
export function resolveAbsolute(community: CommunityId, relativeOrAbsolute: string): string {
  if (/^https?:\/\//.test(relativeOrAbsolute)) return relativeOrAbsolute;
  return new URL(relativeOrAbsolute, communityBaseUrls[community]).toString();
}
