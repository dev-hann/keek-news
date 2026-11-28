import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { BlockedImage } from '../../src/model/blocked_image';
import type { BlockedImageRepo } from '../../src/repository/blocked_image/blocked_image_repo';
import type { ImageHashService } from '../../src/service/image_hash_service';
import { BlockImageUseCase } from '../../src/use_case/block_image_use_case';

/** The repo as a recording double: what a test does not answer stays unanswered. */
function mockBlockedImageRepo() {
  return {
    getAll: vi.fn<() => BlockedImage[]>(),
    add: vi.fn<(image: BlockedImage) => void>(),
    remove: vi.fn<(url: string) => void>(),
    changes: { subscribe: vi.fn<(listener: () => void) => () => void>() },
    isHashBlocked: vi.fn<(hash: string) => boolean>(),
  } satisfies BlockedImageRepo;
}

class FakeImageHashService implements ImageHashService {
  private readonly hash: string | null;

  constructor(hash: string | null) {
    this.hash = hash;
  }

  hashFor(): Promise<string | null> {
    return Promise.resolve(this.hash);
  }
}

/** The one element of a list, as Dart's `.single`. */
const single = <T>(items: T[]): T => {
  expect(items).toHaveLength(1);
  return items[0];
};

let repo: ReturnType<typeof mockBlockedImageRepo>;
let useCase: BlockImageUseCase;

beforeEach(() => {
  repo = mockBlockedImageRepo();
  useCase = new BlockImageUseCase(repo);
});

describe('BlockImageUseCase', () => {
  it('getAll should return right with images', async () => {
    const images: BlockedImage[] = [{ url: 'https://x/a.jpg', blockedAt: new Date(0) }];
    repo.getAll.mockReturnValue(images);

    const result = await useCase.getAll();

    expect(result).toEqual({ ok: true, value: images });
  });

  it('getAll should return left on repo failure', async () => {
    repo.getAll.mockImplementation(() => {
      throw new Error('boom');
    });

    const result = await useCase.getAll();

    expect(result.ok).toBe(false);
  });

  it('add should persist a BlockedImage for the url', async () => {
    repo.add.mockReturnValue(undefined);

    const result = await useCase.add('https://x/a.jpg');

    expect(result).toEqual({ ok: true, value: undefined });
    const captured = single(repo.add.mock.calls.map(([image]) => image));
    expect(captured.url).toBe('https://x/a.jpg');
  });

  it('remove should forward the url', async () => {
    repo.remove.mockReturnValue(undefined);

    const result = await useCase.remove('https://x/a.jpg');

    expect(result).toEqual({ ok: true, value: undefined });
    expect(repo.remove).toHaveBeenCalledExactlyOnceWith('https://x/a.jpg');
  });

  it('changes should forward the repo stream', async () => {
    // The controller behind the repo's stream: its listeners are who `add(null)` reaches.
    const listeners = new Set<() => void>();
    repo.changes.subscribe.mockImplementation((listener) => {
      listeners.add(listener);
      return () => {
        listeners.delete(listener);
      };
    });

    let fired = 0;
    const unsubscribe = useCase.changes.subscribe(() => fired++);
    listeners.forEach((listener) => listener());
    await new Promise<void>((resolve) => setTimeout(resolve, 0));

    expect(fired).toBe(1);
    unsubscribe();
  });
});

describe('BlockImageUseCase fingerprints', () => {
  it('add should capture the fingerprint when hashing succeeds', async () => {
    repo.add.mockReturnValue(undefined);
    const useCaseWithHash = new BlockImageUseCase(
      repo,
      new FakeImageHashService('abcdef0123456789')
    );

    await useCaseWithHash.add('https://x/a.jpg');

    const captured = single(repo.add.mock.calls.map(([image]) => image));
    expect(captured.hash).toBe('abcdef0123456789');
  });

  it('add should store a URL-only entry when hashing fails', async () => {
    repo.add.mockReturnValue(undefined);
    const useCaseNoHash = new BlockImageUseCase(repo, new FakeImageHashService(null));

    await useCaseNoHash.add('https://x/a.jpg');

    const captured = single(repo.add.mock.calls.map(([image]) => image));
    expect(captured.hash).toBeUndefined();
  });

  it('isHashBlocked should delegate to the repo', async () => {
    repo.isHashBlocked.mockReturnValue(true);

    expect(useCase.isHashBlocked('0123456789abcdef')).toBe(true);
    expect(repo.isHashBlocked).toHaveBeenCalledExactlyOnceWith('0123456789abcdef');
  });
});
