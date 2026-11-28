import type { AppRelease, DownloadOutcome, DownloadProgress } from '../../model/app_update';

/** What the app needs to move to its next version: what is released, and what the device can do. */
export interface UpdateRepo {
  /** Whether the app runs in its shell, which relays a request to GitHub. A page in a browser cannot ask. */
  canCheck(): boolean;
  /**
   * The version of the app that is installed, as people read it. Null when the shell is from before
   * the updater and cannot tell; rejects when it can tell, and the reading failed.
   */
  getInstalledVersion(): Promise<string | null>;
  /** The newest release of the app on GitHub. */
  getLatestRelease(): Promise<AppRelease>;
  /** Downloads the file at `url` into the cache of the app, telling `onProgress` how far it is. */
  download(
    url: string,
    onProgress: (progress: DownloadProgress) => void
  ): { result: Promise<DownloadOutcome>; cancel(): void };
  /** Hands the APK at `path` to the system's installer; whether it was started. */
  install(path: string): Promise<boolean>;
  /** Whether the reader allowed the app to install APKs. */
  canInstall(): Promise<boolean>;
  /** Opens the settings where the reader allows that; whether they opened. */
  openInstallSettings(): Promise<boolean>;
}
