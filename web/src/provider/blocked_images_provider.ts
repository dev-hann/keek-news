import type { BlockedImage } from '../model/blocked_image';
import type { Result } from '../model/result';
import { blockImageUseCase } from '../service/service_locator';
import type { BlockImageUseCase } from '../use_case/block_image_use_case';
import { StateNotifier, useNotifierState } from './state_notifier';

/**
 * Read-only mirror of the repo blocklist. All mutations go through
 * BlockedImagesNotifier.block / unblock; the repo's changes stream drives
 * reloads so writes from anywhere (sheet, management screen) stay in sync.
 */
export class BlockedImagesNotifier extends StateNotifier<BlockedImage[]> {
  private readonly useCase: BlockImageUseCase;
  private unsubscribeChanges: (() => void) | undefined;
  private disposed = false;

  constructor(useCase: BlockImageUseCase) {
    super([]);
    this.useCase = useCase;
    this.unsubscribeChanges = useCase.changes.subscribe(() => void this.reload());
    void this.reload();
  }

  private async reload(): Promise<void> {
    const result = await this.useCase.getAll();
    if (!this.disposed && result.ok) this.state = result.value;
  }

  block(url: string): Promise<Result<void>> {
    return this.useCase.add(url);
  }

  unblock(url: string): Promise<Result<void>> {
    return this.useCase.remove(url);
  }

  dispose(): void {
    this.unsubscribeChanges?.();
    this.disposed = true;
  }
}

let blockedImages: BlockedImagesNotifier | undefined;

/** The one blocklist notifier of the app, made the first time a screen asks for it. */
export function blockedImagesNotifier(): BlockedImagesNotifier {
  blockedImages ??= new BlockedImagesNotifier(blockImageUseCase());
  return blockedImages;
}

/** The images the user blocked. */
export function useBlockedImages(): BlockedImage[] {
  return useNotifierState(blockedImagesNotifier());
}
