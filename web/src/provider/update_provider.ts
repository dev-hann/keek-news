import { toast } from 'sonner';
import type {
  AppRelease,
  DownloadOutcome,
  UpdateCheck,
  UpdateState,
  UpdateStatus,
} from '../model/app_update';
import type { Result } from '../model/result';
import { updateUseCase } from '../service/service_locator';
import type { UpdateUseCase } from '../use_case/update_use_case';
import { StateNotifier, useNotifierState } from './state_notifier';

/**
 * A new version is on its way: it is downloaded, downloading, or waiting for the reader. The row
 * is left alone then, and nothing is asked of GitHub again until the app starts anew.
 */
const PENDING: ReadonlySet<UpdateStatus> = new Set([
  'downloading',
  'downloadFailed',
  'ready',
  'permissionNeeded',
  'installFailed',
]);

/** The statuses a download starts from: the new version is known, and no file that can be installed is held. */
const DOWNLOADABLE: ReadonlySet<UpdateStatus> = new Set([
  'available',
  'downloadFailed',
  'installFailed',
]);

/** What the version row of the settings says about a new version of the app. */
export class UpdateNotifier extends StateNotifier<UpdateState> {
  private readonly useCase: UpdateUseCase;
  private downloadTask: { cancel(): void } | null = null;
  private apkPath: string | null = null;
  private checking = false;
  private disposed = false;

  constructor(useCase: UpdateUseCase, buildVersion: string) {
    super({
      status: 'unsupported',
      version: buildVersion,
      support: null,
      release: null,
      percent: null,
    });
    this.useCase = useCase;
    // Not in the shell: nothing can be asked, and the row is what it always was.
    if (!useCase.canCheck()) return;
    this.state = { ...this.state, status: 'checking', version: null };
    document.addEventListener('visibilitychange', this.onVisible);
    void this.look(false);
  }

  /** The settings opened: a new version is looked for, unless one is on its way or a look runs. */
  enter(): void {
    if (this.state.status === 'unsupported' || this.checking) return;
    if (PENDING.has(this.state.status)) return;
    void this.look(false);
  }

  /** Downloads the new version. From `available`, and again from a download or an install that failed. */
  download(): void {
    const { status, release } = this.state;
    if (release === null || !DOWNLOADABLE.has(status)) return;
    const task = this.useCase.download(release, (percent) => this.patch({ percent }));
    this.downloadTask = task;
    this.patch({ status: 'downloading', percent: null });
    void task.result.then((outcome) => this.downloaded(outcome));
  }

  /** Ends the download that runs. The file that did not arrive whole is not kept. */
  cancel(): void {
    if (this.state.status === 'downloading') this.downloadTask?.cancel();
  }

  /**
   * Asks again for what failed: the check, the download, or the install. A look the reader asked
   * for is shown as one, where a look on entering keeps what the row says.
   */
  retry(): void {
    if (this.state.status === 'checkFailed' && !this.checking) void this.look(true);
    if (this.state.status === 'downloadFailed' || this.state.status === 'installFailed') {
      this.download();
    }
  }

  /**
   * Hands the APK to the system's installer. When the installer could not be started, the row says
   * so: no file is held that a tap could install, and only a new download can bring one.
   */
  async install(): Promise<void> {
    if (this.state.status !== 'ready' || this.apkPath === null) return;
    const result = await this.useCase.install(this.apkPath);
    if (result.ok && result.value) return;
    this.apkPath = null;
    this.patch({ status: 'installFailed' });
  }

  /** Opens the settings where the reader allows the app to install APKs. */
  async openInstallSettings(): Promise<void> {
    if (this.state.status !== 'permissionNeeded') return;
    const result = await this.useCase.openInstallSettings();
    if (!result.ok || !result.value) toast.error('설정을 열지 못했어요');
  }

  dispose(): void {
    this.disposed = true;
    document.removeEventListener('visibilitychange', this.onVisible);
  }

  /**
   * Looks for a new version. Nothing was said yet, as on the first visit, or the reader asked for
   * the look: then the row says that it is looking. Else what it says stays until the answer.
   */
  private async look(again: boolean): Promise<void> {
    if (this.disposed) return;
    this.checking = true;
    if (again || this.state.status === 'idle') this.patch({ status: 'checking' });
    const installed = await this.useCase.installed();
    let result: Result<UpdateCheck>;
    if (installed.ok) {
      // The version is said as soon as the shell told it, before GitHub answers.
      this.patch({ version: installed.value.version, support: installed.value.support });
      result = await this.useCase.check(installed.value);
    } else {
      // A version that was never read stays unsaid: one that was read is kept.
      result = installed;
    }
    this.checking = false;
    // The reader may have started a download while the look ran, from the row that stayed.
    if (PENDING.has(this.state.status)) return;
    if (!result.ok) {
      this.patch({ status: 'checkFailed', release: null });
      return;
    }
    const { release, hasNewVersion } = result.value;
    this.patch(
      hasNewVersion ? { status: 'available', release } : { status: 'upToDate', release: null }
    );
  }

  private async downloaded(outcome: DownloadOutcome): Promise<void> {
    this.downloadTask = null;
    if (outcome.type === 'cancelled') {
      this.patch({ status: 'available', percent: null });
      return;
    }
    if (outcome.type === 'failed') {
      this.patch({ status: 'downloadFailed', percent: null });
      return;
    }
    this.apkPath = outcome.path;
    const allowed = await this.useCase.canInstall();
    this.patch({
      status: allowed.ok && allowed.value ? 'ready' : 'permissionNeeded',
      percent: null,
    });
  }

  /** Back from the installer or from its settings: what may have changed is read again. Nothing is asked of GitHub. */
  private readonly onVisible = (): void => {
    const { status, release } = this.state;
    if (document.visibilityState !== 'visible') return;
    if (status === 'ready' && release !== null) void this.installedSince(release);
    if (status === 'permissionNeeded') void this.allowedSince();
  };

  private async installedSince(release: AppRelease): Promise<void> {
    const behind = await this.useCase.isBehind(release);
    if (!behind && this.state.status === 'ready') {
      this.apkPath = null;
      this.patch({ status: 'idle', release: null });
    }
  }

  private async allowedSince(): Promise<void> {
    const allowed = await this.useCase.canInstall();
    if (allowed.ok && allowed.value && this.state.status === 'permissionNeeded') {
      this.patch({ status: 'ready' });
    }
  }

  private patch(change: Partial<UpdateState>): void {
    if (this.disposed) return;
    this.state = { ...this.state, ...change };
  }
}

let update: UpdateNotifier | undefined;

/** The one update notifier of the app, made the first time the settings show the version. */
export function updateNotifier(): UpdateNotifier {
  update ??= new UpdateNotifier(updateUseCase(), __APP_VERSION__);
  return update;
}

/** What the version row says about a new version of the app. */
export function useUpdate(): UpdateState {
  return useNotifierState(updateNotifier());
}
