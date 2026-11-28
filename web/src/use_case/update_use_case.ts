import { isNewerVersion } from '../utils/app_version';
import type { AppRelease, InstalledVersion, UpdateCheck } from '../model/app_update';
import type { Result } from '../model/result';
import type { UpdateRepo } from '../repository/update/update_repo';
import { BaseUseCase } from './base_use_case';

/**
 * The version of the last shell that could not tell its own version: the one from before the
 * updater. A shell that is asked and cannot answer is that one.
 */
const LAST_MANUAL_SHELL = '4.0.0';

/** How far a download is, for people: never all of it before the file is whole, nothing while the size is unknown. */
function percent(bytesWritten: number, totalBytes: number): number | null {
  if (totalBytes <= 0) return null;
  return Math.min(99, Math.floor((bytesWritten / totalBytes) * 100));
}

/** Whether the app has a newer version, and how to get it. */
export class UpdateUseCase extends BaseUseCase {
  private readonly repo: UpdateRepo;

  constructor(repo: UpdateRepo) {
    super();
    this.repo = repo;
  }

  /** Whether GitHub can be asked at all: only the shell of the app relays that request. */
  canCheck(): boolean {
    return this.repo.canCheck();
  }

  /**
   * The app as it is installed, and what its shell can do about a newer version. Asks nothing of
   * the network. A shell from before the updater cannot tell its version: that one is 4.0.0, and
   * installs by hand. A shell that can tell and fails is a failure.
   */
  installed(): Promise<Result<InstalledVersion>> {
    return this.guard(async () => {
      const version = await this.repo.getInstalledVersion();
      return version === null
        ? { version: LAST_MANUAL_SHELL, support: 'manual' }
        : { version, support: 'native' };
    });
  }

  /** The newest release of the app, and whether it is newer than what is installed. */
  check(installed: InstalledVersion): Promise<Result<UpdateCheck>> {
    return this.guard(async () => {
      const release = await this.repo.getLatestRelease();
      return {
        ...installed,
        release,
        hasNewVersion: isNewerVersion(release.version, installed.version),
      };
    });
  }

  /**
   * Whether the app that is installed is behind `release`: it is not, once that version or a newer
   * one is installed. A version that cannot be read leaves it behind: nothing is known to have changed.
   */
  async isBehind(release: AppRelease): Promise<boolean> {
    const installed = await this.installed();
    return !installed.ok || isNewerVersion(release.version, installed.value.version);
  }

  /** Downloads the APK of `release`, telling `onProgress` how far it is. `cancel()` ends it. */
  download(release: AppRelease, onProgress: (percent: number | null) => void) {
    return this.repo.download(release.apkUrl, ({ bytesWritten, totalBytes }) =>
      onProgress(percent(bytesWritten, totalBytes))
    );
  }

  /** Hands the APK at `path` to the installer; whether it was started. */
  install(path: string): Promise<Result<boolean>> {
    return this.guard(() => this.repo.install(path));
  }

  /** Whether the reader allowed the app to install APKs. */
  canInstall(): Promise<Result<boolean>> {
    return this.guard(() => this.repo.canInstall());
  }

  /** Opens the settings where the reader allows that; whether they opened. */
  openInstallSettings(): Promise<Result<boolean>> {
    return this.guard(() => this.repo.openInstallSettings());
  }
}
