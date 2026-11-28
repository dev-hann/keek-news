import type { Failure } from './failures';

/** A release of the app on GitHub: what a reader can move to. */
export interface AppRelease {
  /** The tag of the release, which names the version: `v4.1.0`. */
  tag: string;
  /** The version the tag names: `4.1.0`. */
  version: string;
  /** The page of the release, with its notes. */
  pageUrl: string;
  /** Where the APK of the release is. */
  apkUrl: string;
}

/**
 * What the shell the app runs in can do about a new version. `manual`: a shell from before the
 * updater, which cannot tell its own version; the reader gets the new one from the Release page.
 */
export type UpdateSupport = 'manual' | 'native';

/** The app as it is installed: the version people read, and what its shell can do about a newer one. */
export interface InstalledVersion {
  version: string;
  support: UpdateSupport;
}

/** What a check found: the newest release, and whether it is newer than the app that is installed. */
export interface UpdateCheck extends InstalledVersion {
  release: AppRelease;
  hasNewVersion: boolean;
}

/** How far a download is. `totalBytes` is -1 when the server did not say. */
export interface DownloadProgress {
  bytesWritten: number;
  totalBytes: number;
}

/** How a download ended. One that was cancelled did not fail: nothing went wrong. */
export type DownloadOutcome =
  | { type: 'downloaded'; path: string }
  | { type: 'cancelled' }
  | { type: 'failed'; failure: Failure };

/**
 * What the version row says about a new version of the app. `unsupported`: the app is not in its
 * shell, and nothing is asked. `idle`: a version, and nothing said about a newer one. `ready`:
 * downloaded, and the installer is a tap away. `installFailed`: the installer could not be
 * started, so no file is held that a tap could install.
 */
export type UpdateStatus =
  | 'unsupported'
  | 'idle'
  | 'checking'
  | 'upToDate'
  | 'available'
  | 'downloading'
  | 'downloadFailed'
  | 'ready'
  | 'permissionNeeded'
  | 'installFailed'
  | 'checkFailed';

/** The version row of the settings: what it says, and what it knows. */
export interface UpdateState {
  status: UpdateStatus;
  /**
   * The version the row names, as people read it: the one that is installed, or the one that
   * was built where there is no shell. Null until the shell said it.
   */
  version: string | null;
  /** What the shell can do with a new version. Null in a browser, which has no shell. */
  support: UpdateSupport | null;
  /** The release that can be installed, once a check found a newer one. */
  release: AppRelease | null;
  /** How far the download is, 0 to 99. Null while the size is not known. */
  percent: number | null;
}
