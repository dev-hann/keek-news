import { describe, expect, it, vi } from 'vitest';
import type { ApkInstaller } from '@gyo-community/app-launcher';
import type { PackageInfo } from '@gyo-community/device-info';
import {
  DownloadCancelledError,
  type DownloadResult,
  type Downloader,
  type DownloadTask,
} from '@gyo-community/http';
import { UpdateImpl } from '../../../src/repository/update/update_impl';
import type { GitHubRemoteService } from '../../../src/service/github_remote_service';

const file = (path: string): DownloadResult => ({
  path,
  bytesWritten: 10,
  status: 200,
  url: 'https://example.com/app.apk',
  headers: {},
});

function parts(available: boolean) {
  return {
    relay: { isAvailable: vi.fn(() => available) },
    gitHub: { getLatestRelease: vi.fn<GitHubRemoteService['getLatestRelease']>() },
    packageInfo: { getInfo: vi.fn<PackageInfo['getInfo']>() },
    downloader: { download: vi.fn<Downloader['download']>() },
    installer: {
      install: vi.fn<ApkInstaller['install']>(),
      canInstall: vi.fn<ApkInstaller['canInstall']>(),
      openInstallSettings: vi.fn<ApkInstaller['openInstallSettings']>(),
    },
  };
}

function repoOf(available = true) {
  const p = parts(available);
  return {
    repo: new UpdateImpl(p.relay, p.gitHub, p.packageInfo, p.downloader, p.installer),
    ...p,
  };
}

/** A download the test ends when it chooses to. */
function pending() {
  let end: (file: DownloadResult) => void = () => undefined;
  let fail: (error: unknown) => void = () => undefined;
  const cancel = vi.fn();
  const task: DownloadTask = {
    result: new Promise((resolve, reject) => {
      end = resolve;
      fail = reject;
    }),
    cancel,
  };
  return { task, cancel, end: (f: DownloadResult) => end(f), fail: (e: unknown) => fail(e) };
}

describe('UpdateImpl', () => {
  it('can check where the relay is: in the shell, and not in a browser', () => {
    expect(repoOf(true).repo.canCheck()).toBe(true);
    expect(repoOf(false).repo.canCheck()).toBe(false);
  });

  it('reads the installed version as Android has it', async () => {
    const { repo, packageInfo } = repoOf();
    packageInfo.getInfo.mockResolvedValue({
      packageName: 'com.keek_news.app',
      appName: '킥뉴스',
      versionName: '4.1.0',
      versionCode: 40100,
    });

    await expect(repo.getInstalledVersion()).resolves.toBe('4.1.0');
  });

  it('says nothing for a shell without a handler for the installed app, which is from before the updater', async () => {
    const { repo, packageInfo } = repoOf();
    packageInfo.getInfo.mockRejectedValue(new Error("Bridge 'device_info' not found"));

    await expect(repo.getInstalledVersion()).resolves.toBeNull();
  });

  it('does not take a reading that failed for a shell from before the updater', async () => {
    const { repo, packageInfo } = repoOf();
    packageInfo.getInfo.mockRejectedValue(
      new Error("Bridge method 'get_package_info' timed out after 30000ms")
    );
    await expect(repo.getInstalledVersion()).rejects.toThrow('timed out');

    packageInfo.getInfo.mockRejectedValue(new Error('Unknown method: get_package_info'));
    await expect(repo.getInstalledVersion()).rejects.toThrow('Unknown method');
  });

  it('asks the latest release where it is read', async () => {
    const { repo, gitHub } = repoOf();
    const release = {
      tag: 'v4.1.0',
      version: '4.1.0',
      pageUrl: 'https://github.com/dev-hann/keek-news/releases/tag/v4.1.0',
      apkUrl: 'https://github.com/dev-hann/keek-news/releases/download/v4.1.0/keek-news-v4.1.0.apk',
    };
    gitHub.getLatestRelease.mockResolvedValue(release);

    await expect(repo.getLatestRelease()).resolves.toEqual(release);
  });

  it('downloads the address it is given, and tells the progress as it comes', async () => {
    const { repo, downloader } = repoOf();
    const download = pending();
    downloader.download.mockReturnValue(download.task);
    const onProgress = vi.fn();

    const started = repo.download('https://example.com/app.apk', onProgress);

    expect(downloader.download).toHaveBeenCalledWith(
      { url: 'https://example.com/app.apk' },
      { onProgress }
    );
    expect(onProgress).not.toHaveBeenCalled();
    download.end(file('/cache/downloads/app.apk'));
    await expect(started.result).resolves.toEqual({
      type: 'downloaded',
      path: '/cache/downloads/app.apk',
    });
  });

  it('ends a download the page no longer wants, and says that it was cancelled, not that it failed', async () => {
    const { repo, downloader } = repoOf();
    const download = pending();
    downloader.download.mockReturnValue(download.task);

    const started = repo.download('https://example.com/app.apk', vi.fn());
    started.cancel();
    expect(download.cancel).toHaveBeenCalledTimes(1);
    download.fail(new DownloadCancelledError());

    await expect(started.result).resolves.toEqual({ type: 'cancelled' });
  });

  it('says a download that failed as a network failure, with what the plugin said', async () => {
    const { repo, downloader } = repoOf();
    const download = pending();
    downloader.download.mockReturnValue(download.task);

    const started = repo.download('https://example.com/app.apk', vi.fn());
    download.fail(new Error('HTTP 404'));
    const outcome = await started.result;

    expect(outcome.type).toBe('failed');
    expect(outcome).toMatchObject({ type: 'failed', failure: { kind: 'NetworkFailure' } });
    expect((outcome as { failure: Error }).failure.message).toBe('HTTP 404');
  });

  it('hands the installer its three questions', async () => {
    const { repo, installer } = repoOf();
    installer.install.mockResolvedValue(true);
    installer.canInstall.mockResolvedValue(false);
    installer.openInstallSettings.mockResolvedValue(true);

    await expect(repo.install('/cache/downloads/app.apk')).resolves.toBe(true);
    await expect(repo.canInstall()).resolves.toBe(false);
    await expect(repo.openInstallSettings()).resolves.toBe(true);
    expect(installer.install).toHaveBeenCalledWith({ path: '/cache/downloads/app.apk' });
  });
});
