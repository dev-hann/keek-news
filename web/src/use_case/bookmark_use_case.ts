import type { Bookmark } from '../model/bookmark';
import type { CommunityId } from '../model/community';
import type { Result } from '../model/result';
import type { BookmarkRepo } from '../repository/bookmark/bookmark_repo';
import { BaseUseCase } from './base_use_case';

export class BookmarkUseCase extends BaseUseCase {
  private readonly repo: BookmarkRepo;

  constructor(repo: BookmarkRepo) {
    super();
    this.repo = repo;
  }

  getAll(): Promise<Result<Bookmark[]>> {
    return this.guard(async () => this.repo.getAll());
  }

  isBookmarked(community: CommunityId, id: string): Promise<Result<boolean>> {
    return this.guard(async () => this.repo.isBookmarked(community, id));
  }

  add(bookmark: Bookmark): Promise<Result<void>> {
    return this.guard(async () => this.repo.add(bookmark));
  }

  remove(community: CommunityId, id: string): Promise<Result<void>> {
    return this.guard(async () => this.repo.remove(community, id));
  }
}
