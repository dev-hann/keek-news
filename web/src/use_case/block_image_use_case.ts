import type { BlockedImage } from '../model/blocked_image';
import type { Result } from '../model/result';
import type {
  BlockedImageRepo,
  ChangeStream,
} from '../repository/blocked_image/blocked_image_repo';
import type { ImageHashService } from '../service/image_hash_service';
import { BaseUseCase } from './base_use_case';

export class BlockImageUseCase extends BaseUseCase {
  private readonly repo: BlockedImageRepo;
  private readonly hashService: ImageHashService | undefined;

  constructor(repo: BlockedImageRepo, hashService?: ImageHashService) {
    super();
    this.repo = repo;
    this.hashService = hashService;
  }

  /** Fires after every persisted mutation; forwarded from the repo so the provider layer never needs the repo directly. */
  get changes(): ChangeStream {
    return this.repo.changes;
  }

  /** Whether `hash` fingerprint-matches a blocked image (render-time check). */
  isHashBlocked(hash: string): boolean {
    return this.repo.isHashBlocked(hash);
  }

  getAll(): Promise<Result<BlockedImage[]>> {
    return this.guard(async () => this.repo.getAll());
  }

  add(url: string): Promise<Result<void>> {
    return this.guard(async () => {
      const hash = await this.hashService?.hashFor(url);
      this.repo.add({ url, blockedAt: new Date(), ...(hash != null ? { hash } : {}) });
    });
  }

  remove(url: string): Promise<Result<void>> {
    return this.guard(async () => this.repo.remove(url));
  }
}
