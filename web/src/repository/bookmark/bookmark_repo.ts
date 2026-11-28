import type { Bookmark } from '../../model/bookmark';
import type { CommunityId } from '../../model/community';

/** The posts the user saved, most recently saved first. */
export interface BookmarkRepo {
  getAll(): Bookmark[];

  isBookmarked(community: CommunityId, id: string): boolean;

  add(bookmark: Bookmark): void;

  remove(community: CommunityId, id: string): void;
}
