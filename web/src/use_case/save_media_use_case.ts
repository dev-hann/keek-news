import type { MediaSaveResult } from '../model/media_save_failure';
import type { MediaTarget } from '../model/media_target';
import type { MediaSaveRepo } from '../repository/media_save/media_save_repo';

export class SaveMediaUseCase {
  private readonly repo: MediaSaveRepo;

  constructor(repo: MediaSaveRepo) {
    this.repo = repo;
  }

  call(target: MediaTarget): Promise<MediaSaveResult> {
    switch (target.kind) {
      case 'image':
        return this.repo.saveImage(target.url);
      case 'video':
        return this.repo.saveVideo(target.url);
      case 'external':
        return Promise.resolve({ ok: false, failure: { type: 'unexpected' } });
    }
  }
}
