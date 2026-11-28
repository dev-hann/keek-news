import { describe, expect, it, onTestFinished } from 'vitest';
import type { BlockedImage } from '../../src/model/blocked_image';
import { BlockedImagesNotifier } from '../../src/provider/blocked_images_provider';
import type { BlockedImageRepo } from '../../src/repository/blocked_image/blocked_image_repo';
import { FlutterImageHashService } from '../../src/service/image_hash_service';
import { BlockImageUseCase } from '../../src/use_case/block_image_use_case';

/**
 * In-memory blocklist double: tracks blocked URLs (newest first) and
 * broadcasts `BlockedImageRepo.changes` after each mutation.
 */
class StubBlockedImageRepo implements BlockedImageRepo {
  private images: BlockedImage[] = [];
  private readonly listeners = new Set<() => void>();

  readonly addedUrls: string[] = [];
  readonly removedUrls: string[] = [];

  readonly changes = {
    subscribe: (listener: () => void) => {
      this.listeners.add(listener);
      return () => {
        this.listeners.delete(listener);
      };
    },
  };

  get blockedUrls(): string[] {
    return this.images.map((image) => image.url);
  }

  getAll(): BlockedImage[] {
    return [...this.images];
  }

  add(image: BlockedImage): void {
    this.addedUrls.push(image.url);
    this.images = this.images.filter((b) => b.url !== image.url);
    this.images.unshift(image);
    this.notify();
  }

  remove(url: string): void {
    this.removedUrls.push(url);
    this.images = this.images.filter((b) => b.url !== url);
    this.notify();
  }

  isHashBlocked(hash: string): boolean {
    for (const image of this.images) {
      const blocked = image.hash;
      if (blocked === undefined) continue;
      if (FlutterImageHashService.matches(hash, blocked)) {
        return true;
      }
    }
    return false;
  }

  private notify(): void {
    this.listeners.forEach((listener) => listener());
  }
}

/**
 * A turn of the event loop, after which every load the notifier has started
 * has settled: what `Future<void>.delayed(Duration.zero)` was in the Dart test.
 */
const tick = (): Promise<void> => new Promise<void>((resolve) => setTimeout(resolve, 0));

/** The provider over a stub repo: the Dart test's container with the use case overridden. */
const providerOver = (repo: StubBlockedImageRepo): BlockedImagesNotifier => {
  const notifier = new BlockedImagesNotifier(new BlockImageUseCase(repo));
  onTestFinished(() => notifier.dispose());
  return notifier;
};

describe('blockedImagesProvider', () => {
  it('should load the blocklist on creation', async () => {
    const repo = new StubBlockedImageRepo();
    repo.add({ url: 'https://x/a.jpg', blockedAt: new Date(0) });

    // Reading the notifier creates the provider; its initial async load
    // settles after a microtask tick.
    const notifier = providerOver(repo);
    await tick();

    expect(notifier.getState().map((b) => b.url)).toEqual(['https://x/a.jpg']);
  });

  it('should reload when the repo emits changes', async () => {
    const repo = new StubBlockedImageRepo();
    const notifier = providerOver(repo);
    await tick();
    expect(notifier.getState()).toEqual([]);

    await notifier.block('https://x/b.jpg');
    await tick();

    expect(notifier.getState().map((b) => b.url)).toEqual(['https://x/b.jpg']);
  });

  it('unblock should remove the url through the repo', async () => {
    const repo = new StubBlockedImageRepo();
    repo.add({ url: 'https://x/a.jpg', blockedAt: new Date(0) });
    const notifier = providerOver(repo);
    await tick();

    await notifier.unblock('https://x/a.jpg');
    await tick();

    expect(notifier.getState()).toEqual([]);
    expect(repo.removedUrls).toEqual(['https://x/a.jpg']);
  });

  // Added for the web: the Dart suite never looked at dispose.
  it('stops following the repo once disposed', async () => {
    const repo = new StubBlockedImageRepo();
    const notifier = providerOver(repo);
    await tick();

    notifier.dispose();
    repo.add({ url: 'https://x/late.jpg', blockedAt: new Date(0) });
    await tick();

    expect(notifier.getState()).toEqual([]);
  });
});
