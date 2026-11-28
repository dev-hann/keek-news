import {
  blockedImageFromJson,
  blockedImageToJson,
  type BlockedImage,
} from '../../model/blocked_image';
import { FlutterImageHashService } from '../../service/image_hash_service';
import type { LocalStorageService } from '../../service/local_storage_service';
import type { BlockedImageRepo, ChangeStream } from './blocked_image_repo';

const STORAGE_KEY = 'blocked_images';

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value);

export class BlockedImageImpl implements BlockedImageRepo {
  private readonly storage: LocalStorageService;
  private readonly listeners = new Set<() => void>();
  readonly changes: ChangeStream;

  /** Parsed blocklist cache so render-time hash checks stay synchronous. */
  private cache: BlockedImage[] | undefined;

  constructor(storage: LocalStorageService) {
    this.storage = storage;
    this.changes = {
      subscribe: (listener) => {
        this.listeners.add(listener);
        return () => {
          this.listeners.delete(listener);
        };
      },
    };
  }

  getAll(): BlockedImage[] {
    return this.ensureCache();
  }

  add(image: BlockedImage): void {
    const all = this.ensureCache();
    const filtered = all.filter((b) => b.url !== image.url);
    this.persist([image, ...filtered]);
  }

  remove(url: string): void {
    const all = this.ensureCache();
    const filtered = all.filter((b) => b.url !== url);
    this.persist(filtered);
  }

  isHashBlocked(hash: string): boolean {
    for (const image of this.ensureCache()) {
      const blocked = image.hash;
      if (blocked === undefined) continue;
      if (FlutterImageHashService.matches(hash, blocked)) {
        return true;
      }
    }
    return false;
  }

  /**
   * Parsed blocklist cache so render-time hash checks stay synchronous;
   * storage reads are sync and this repo is the only writer.
   */
  private ensureCache(): BlockedImage[] {
    this.cache ??= this.decode(this.storage.getString(STORAGE_KEY));
    return this.cache;
  }

  private persist(images: BlockedImage[]): void {
    this.cache = images;
    this.storage.setString(STORAGE_KEY, JSON.stringify(images.map(blockedImageToJson)));
    this.listeners.forEach((listener) => listener());
  }

  private decode(raw: string | null): BlockedImage[] {
    if (raw === null) return [];
    try {
      const decoded: unknown = JSON.parse(raw);
      if (!Array.isArray(decoded)) return [];

      const result: BlockedImage[] = [];
      for (const entry of decoded) {
        if (!isRecord(entry)) continue;
        try {
          result.push(blockedImageFromJson(entry));
        } catch {
          continue;
        }
      }
      return result;
    } catch {
      return [];
    }
  }
}
