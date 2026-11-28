import { ApkInstaller } from '@gyo-community/app-launcher';
import { PackageInfo } from '@gyo-community/device-info';
import { DownloadCancelledError, type Downloader, type Http } from '@gyo-community/http';
import type { AppRelease, DownloadOutcome, DownloadProgress } from '../../model/app_update';
import { NetworkFailure } from '../../model/failures';
import type { GitHubRemoteService } from '../../service/github_remote_service';
import type { UpdateRepo } from './update_repo';

/**
 * What the core of the bridge answers for a bridge the shell has no handler for. Only a shell from
 * before the updater has none for the installed app; a shell that has one and fails says another thing.
 */
const NO_HANDLER = /^Bridge 'device_info' not found$/;

/** The update of the app, over GitHub and the three native abilities of its shell. */
export class UpdateImpl implements UpdateRepo {
  private readonly relay: Pick<Http, 'isAvailable'>;
  private readonly gitHub: Pick<GitHubRemoteService, 'getLatestRelease'>;
  private readonly packageInfo: Pick<PackageInfo, 'getInfo'>;
  private readonly downloader: Pick<Downloader, 'download'>;
  private readonly installer: Pick<ApkInstaller, 'install' | 'canInstall' | 'openInstallSettings'>;

  constructor(
    relay: Pick<Http, 'isAvailable'>,
    gitHub: Pick<GitHubRemoteService, 'getLatestRelease'>,
    packageInfo: Pick<PackageInfo, 'getInfo'>,
    downloader: Pick<Downloader, 'download'>,
    installer: Pick<ApkInstaller, 'install' | 'canInstall' | 'openInstallSettings'>
  ) {
    this.relay = relay;
    this.gitHub = gitHub;
    this.packageInfo = packageInfo;
    this.downloader = downloader;
    this.installer = installer;
  }

  canCheck(): boolean {
    return this.relay.isAvailable();
  }

  async getInstalledVersion(): Promise<string | null> {
    try {
      return (await this.packageInfo.getInfo()).versionName;
    } catch (error) {
      if (error instanceof Error && NO_HANDLER.test(error.message)) return null;
      throw error;
    }
  }

  getLatestRelease(): Promise<AppRelease> {
    return this.gitHub.getLatestRelease();
  }

  download(
    url: string,
    onProgress: (progress: DownloadProgress) => void
  ): { result: Promise<DownloadOutcome>; cancel(): void } {
    const task = this.downloader.download({ url }, { onProgress });
    return {
      result: task.result.then(
        (file): DownloadOutcome => ({ type: 'downloaded', path: file.path }),
        (error: unknown): DownloadOutcome =>
          error instanceof DownloadCancelledError
            ? { type: 'cancelled' }
            : { type: 'failed', failure: new NetworkFailure(messageOf(error)) }
      ),
      cancel: () => task.cancel(),
    };
  }

  install(path: string): Promise<boolean> {
    return this.installer.install({ path });
  }

  canInstall(): Promise<boolean> {
    return this.installer.canInstall();
  }

  openInstallSettings(): Promise<boolean> {
    return this.installer.openInstallSettings();
  }
}

function messageOf(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
