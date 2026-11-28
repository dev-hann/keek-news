import { describe, expect, it } from 'vitest';
import type { AppRelease, DownloadOutcome, DownloadProgress } from '../../src/model/app_update';
import { NetworkFailure, ServerFailure } from '../../src/model/failures';
import type { UpdateRepo } from '../../src/repository/update/update_repo';
import { UpdateUseCase } from '../../src/use_case/update_use_case';

const release = (version: string): AppRelease => ({
  tag: `v${version}`,
  version,
  pageUrl: `https://github.com/dev-hann/keek-news/releases/tag/v${version}`,
  apkUrl: `https://github.com/dev-hann/keek-news/releases/download/v${version}/keek-news.apk`,
});

/** A repo that answers what each test tells it to, and remembers what it was asked. */
class StubUpdateRepo implements UpdateRepo {
  canCheckAnswer = true;
  installedVersion: string | null | Error = '4.0.0';
  latestRelease: AppRelease | Error = release('4.1.0');
  installAnswer: boolean | Error = true;
  canInstallAnswer: boolean | Error = false;
  settingsAnswer: boolean | Error = true;

  readonly downloads: string[] = [];
  readonly installs: string[] = [];
  progress: ((progress: DownloadProgress) => void) | null = null;
  outcome: DownloadOutcome = { type: 'downloaded', path: '/cache/downloads/app.apk' };
  readonly cancelled: string[] = [];

  canCheck(): boolean {
    return this.canCheckAnswer;
  }

  async getInstalledVersion(): Promise<string | null> {
    return answer(this.installedVersion);
  }

  async getLatestRelease(): Promise<AppRelease> {
    return answer(this.latestRelease);
  }

  download(url: string, onProgress: (progress: DownloadProgress) => void) {
    this.downloads.push(url);
    this.progress = onProgress;
    return { result: Promise.resolve(this.outcome), cancel: () => this.cancelled.push(url) };
  }

  async install(path: string): Promise<boolean> {
    this.installs.push(path);
    return answer(this.installAnswer);
  }

  canInstall(): Promise<boolean> {
    return answer(this.canInstallAnswer);
  }

  openInstallSettings(): Promise<boolean> {
    return answer(this.settingsAnswer);
  }
}

/** What a stub answers: the value, or the error thrown. */
async function answer<T>(value: T | Error): Promise<T> {
  if (value instanceof Error) throw value;
  return value;
}

describe('UpdateUseCase', () => {
  it('says whether GitHub can be asked, as the repo does', () => {
    const repo = new StubUpdateRepo();
    const useCase = new UpdateUseCase(repo);
    expect(useCase.canCheck()).toBe(true);
    repo.canCheckAnswer = false;
    expect(useCase.canCheck()).toBe(false);
  });

  it('reads the installed version, and that the shell can install', async () => {
    const repo = new StubUpdateRepo();
    repo.installedVersion = '4.1.0';

    await expect(new UpdateUseCase(repo).installed()).resolves.toEqual({
      ok: true,
      value: { version: '4.1.0', support: 'native' },
    });
  });

  it('takes a shell that has no way to tell its version for 4.0.0, which installs by hand', async () => {
    const repo = new StubUpdateRepo();
    repo.installedVersion = null;

    await expect(new UpdateUseCase(repo).installed()).resolves.toEqual({
      ok: true,
      value: { version: '4.0.0', support: 'manual' },
    });
  });

  it('answers a reading that failed as a failure, not as the 4.0.0 shell', async () => {
    const repo = new StubUpdateRepo();
    repo.installedVersion = new Error("Bridge method 'get_package_info' timed out after 30000ms");

    const result = await new UpdateUseCase(repo).installed();

    expect(result).toMatchObject({ ok: false, failure: { kind: 'ServerFailure' } });
  });

  it('finds a newer release', async () => {
    const repo = new StubUpdateRepo();
    const useCase = new UpdateUseCase(repo);
    const installed = { version: '4.0.0', support: 'native' as const };

    await expect(useCase.check(installed)).resolves.toEqual({
      ok: true,
      value: { ...installed, release: release('4.1.0'), hasNewVersion: true },
    });
  });

  it('finds nothing newer for the version that is installed', async () => {
    const repo = new StubUpdateRepo();
    repo.latestRelease = release('4.0.0');
    const useCase = new UpdateUseCase(repo);
    const installed = { version: '4.0.0', support: 'manual' as const };

    const result = await useCase.check(installed);

    expect(result).toMatchObject({ ok: true, value: { hasNewVersion: false, support: 'manual' } });
  });

  it('answers a failed check with the failure the client threw, not by throwing', async () => {
    const repo = new StubUpdateRepo();
    repo.latestRelease = new ServerFailure('HTTP 403');

    const result = await new UpdateUseCase(repo).check({ version: '4.0.0', support: 'native' });

    expect(result).toMatchObject({ ok: false, failure: { kind: 'ServerFailure' } });
  });

  it('says whether the app that is installed is behind a release', async () => {
    const repo = new StubUpdateRepo();
    repo.installedVersion = '4.1.0';
    const useCase = new UpdateUseCase(repo);

    await expect(useCase.isBehind(release('4.1.0'))).resolves.toBe(false);
    await expect(useCase.isBehind(release('4.0.9'))).resolves.toBe(false);
    await expect(useCase.isBehind(release('4.2.0'))).resolves.toBe(true);
  });

  it('leaves the app behind a release while its version cannot be read', async () => {
    const repo = new StubUpdateRepo();
    repo.installedVersion = new Error('timed out');

    await expect(new UpdateUseCase(repo).isBehind(release('4.1.0'))).resolves.toBe(true);
  });

  it('downloads the APK of the release, and tells how far it is', async () => {
    const repo = new StubUpdateRepo();
    const useCase = new UpdateUseCase(repo);
    const told: Array<number | null> = [];

    const download = useCase.download(release('4.1.0'), (percent) => told.push(percent));
    repo.progress?.({ bytesWritten: 0, totalBytes: 2_000_000 });
    repo.progress?.({ bytesWritten: 900_000, totalBytes: 2_000_000 });
    repo.progress?.({ bytesWritten: 2_000_000, totalBytes: 2_000_000 });

    expect(repo.downloads).toEqual([release('4.1.0').apkUrl]);
    expect(told).toEqual([0, 45, 99]);
    await expect(download.result).resolves.toEqual({
      type: 'downloaded',
      path: '/cache/downloads/app.apk',
    });
  });

  it('tells nothing about how far a download is while its size is unknown', async () => {
    const repo = new StubUpdateRepo();
    const told: Array<number | null> = [];

    new UpdateUseCase(repo).download(release('4.1.0'), (percent) => told.push(percent));
    repo.progress?.({ bytesWritten: 500, totalBytes: -1 });
    repo.progress?.({ bytesWritten: 900, totalBytes: 0 });

    expect(told).toEqual([null, null]);
  });

  it('ends a download when told to', () => {
    const repo = new StubUpdateRepo();
    const download = new UpdateUseCase(repo).download(release('4.1.0'), () => undefined);

    download.cancel();

    expect(repo.cancelled).toEqual([release('4.1.0').apkUrl]);
  });

  it('hands a path to the installer, and says whether the installer was started', async () => {
    const repo = new StubUpdateRepo();
    const useCase = new UpdateUseCase(repo);

    await expect(useCase.install('/cache/downloads/app.apk')).resolves.toEqual({
      ok: true,
      value: true,
    });
    expect(repo.installs).toEqual(['/cache/downloads/app.apk']);
  });

  it('answers an installer that could not be started with its failure', async () => {
    const repo = new StubUpdateRepo();
    repo.installAnswer = new Error('No file at path');

    const result = await new UpdateUseCase(repo).install('/cache/downloads/gone.apk');

    expect(result).toMatchObject({ ok: false, failure: { kind: 'ServerFailure' } });
  });

  it('asks whether the app may install, and opens the settings where it is allowed', async () => {
    const repo = new StubUpdateRepo();
    const useCase = new UpdateUseCase(repo);

    repo.canInstallAnswer = true;
    repo.settingsAnswer = false;
    await expect(useCase.canInstall()).resolves.toEqual({ ok: true, value: true });
    await expect(useCase.openInstallSettings()).resolves.toEqual({ ok: true, value: false });
  });

  it('answers a failure of the repo as it came, and any other error as a server failure', async () => {
    const repo = new StubUpdateRepo();
    const useCase = new UpdateUseCase(repo);
    const failure = new NetworkFailure('timeout');

    repo.canInstallAnswer = failure;
    await expect(useCase.canInstall()).resolves.toEqual({ ok: false, failure });

    repo.settingsAnswer = new Error('no activity');
    const result = await useCase.openInstallSettings();
    expect(result).toMatchObject({ ok: false, failure: { kind: 'ServerFailure' } });
  });
});
