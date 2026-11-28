import type { LocalStorageService } from './local_storage_service';

/** The storage of the page's origin. A list is kept as JSON. */
export class BrowserLocalStorageService implements LocalStorageService {
  private readonly storage: Storage;

  constructor(storage: Storage = window.localStorage) {
    this.storage = storage;
  }

  getString(key: string): string | null {
    return this.storage.getItem(key);
  }

  setString(key: string, value: string): void {
    this.storage.setItem(key, value);
  }

  getStringList(key: string): string[] | null {
    const raw = this.storage.getItem(key);
    if (raw === null) return null;
    try {
      const parsed: unknown = JSON.parse(raw);
      return Array.isArray(parsed) ? parsed.map(String) : null;
    } catch {
      return null;
    }
  }

  setStringList(key: string, value: string[]): void {
    this.storage.setItem(key, JSON.stringify(value));
  }

  containsKey(key: string): boolean {
    return this.storage.getItem(key) !== null;
  }

  remove(key: string): void {
    this.storage.removeItem(key);
  }
}
