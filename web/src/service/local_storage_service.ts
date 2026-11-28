/** Key–value storage that outlives the app. Values are text. */
export interface LocalStorageService {
  getString(key: string): string | null;
  setString(key: string, value: string): void;
  /** null when the key holds nothing or not a list. */
  getStringList(key: string): string[] | null;
  setStringList(key: string, value: string[]): void;
  containsKey(key: string): boolean;
  remove(key: string): void;
}
