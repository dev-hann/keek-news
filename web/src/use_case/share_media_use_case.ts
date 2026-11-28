import type { MediaSaveResult } from '../model/media_save_failure';
import type { MediaTarget } from '../model/media_target';
import type { MediaSaveRepo } from '../repository/media_save/media_save_repo';

export class ShareMediaUseCase {
  private readonly repo: MediaSaveRepo;

  constructor(repo: MediaSaveRepo) {
    this.repo = repo;
  }

  call(target: MediaTarget): Promise<MediaSaveResult> {
    return this.repo.share(target);
  }
}
