import type { BlockedImage } from '../../model/blocked_image';

/** Events with nothing in them: `subscribe` returns what detaches the listener. */
export interface ChangeStream {
  subscribe(listener: () => void): () => void;
}

/**
 * Local blocklist of images. `changes` fires after every persisted mutation
 * so provider mirrors can reload without owning the writes.
 */
export interface BlockedImageRepo {
  getAll(): BlockedImage[];

  add(image: BlockedImage): void;

  remove(url: string): void;

  readonly changes: ChangeStream;

  /** Whether `hash` fingerprint-matches any blocked image (small Hamming distance). Sync so render-time checks never await. */
  isHashBlocked(hash: string): boolean;
}
