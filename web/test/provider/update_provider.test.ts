// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { toast } from 'sonner';
import type {
  AppRelease,
  DownloadOutcome,
  InstalledVersion,
  UpdateCheck,
} from '../../src/model/app_update';
import { NetworkFailure } from '../../src/model/failures';
import type { Result } from '../../src/model/result';
import { UpdateNotifier } from '../../src/provider/update_provider';
import type { UpdateUseCase } from '../../src/use_case/update_use_case';

vi.mock('sonner', () => ({ toast: { error: vi.fn(), success: vi.fn() } }));

const RELEASE: AppRelease = {
  tag: 'v4.1.0',
  version: '4.1.0',
  pageUrl: 'https://github.com/dev-hann/keek-news/releases/tag/v4.1.0',
  apkUrl: 'https://github.com/dev-hann/keek-news/releases/download/v4.1.0/keek-news.apk',
};
const INSTALLED: InstalledVersion = { version: '4.0.0', support: 'native' };
const MANUAL: InstalledVersion = { version: '4.0.0', support: 'manual' };
const available = (): Result<UpdateCheck> => ({
  ok: true,
  value: { ...INSTALLED, release: RELEASE, hasNewVersion: true },
});
const upToDate = (): Result<UpdateCheck> => ({
  ok: true,
  value: { ...INSTALLED, release: RELEASE, hasNewVersion: false },
});
const WHOLE: DownloadOutcome = { type: 'downloaded', path: '/cache/downloads/keek-news.apk' };
const ok = <T>(value: T): Result<T> => ({ ok: true, value });
const NOT_FOUND: DownloadOutcome = {
  type: 'failed',
  failure: new NetworkFailure('HTTP 404'),
};

/** A promise the test ends when it chooses to. */
function deferred<T>() {
  let resolve: (value: T) => void = () => undefined;
  const promise = new Promise<T>((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

/** What the notifier started by now, finished. */
const flush = (): Promise<void> => new Promise((done) => setTimeout(done, 0));

const spyVisibility = () => vi.spyOn(document, 'visibilityState', 'get');

/** What the use case answers, each answer set by the test. */
class FakeUseCase {
  canCheck = vi.fn<() => boolean>(() => true);
  installed = vi.fn<UpdateUseCase['installed']>();
  check = vi.fn<UpdateUseCase['check']>();
  isBehind = vi.fn<UpdateUseCase['isBehind']>();
  download = vi.fn<UpdateUseCase['download']>();
  install = vi.fn<UpdateUseCase['install']>();
  canInstall = vi.fn<UpdateUseCase['canInstall']>();
  openInstallSettings = vi.fn<UpdateUseCase['openInstallSettings']>();

  /** Each download the notifier starts, in order: the test ends it when it chooses to. */
  readonly downloads: Array<{
    end: (outcome: DownloadOutcome) => void;
    cancel: ReturnType<typeof vi.fn>;
    tell: (percent: number | null) => void;
  }> = [];

  /** A shell that answers at once: 4.0.0 is installed, 4.1.0 is released, and the app may install. */
  asShell(): this {
    this.installed.mockResolvedValue(ok(INSTALLED));
    this.check.mockResolvedValue(available());
    this.isBehind.mockResolvedValue(true);
    this.canInstall.mockResolvedValue({ ok: true, value: true });
    return this;
  }

  /** Makes every download hang until the test ends it. */
  hangDownloads(): void {
    this.download.mockImplementation((_release, onProgress) => {
      const outcome = deferred<DownloadOutcome>();
      const cancel = vi.fn();
      this.downloads.push({ end: (ended) => outcome.resolve(ended), cancel, tell: onProgress });
      return { result: outcome.promise, cancel };
    });
  }

  get useCase(): UpdateUseCase {
    return this as unknown as UpdateUseCase;
  }
}

describe('UpdateNotifier', () => {
  let notifier: UpdateNotifier | undefined;
  let visibility: ReturnType<typeof spyVisibility>;

  const make = (fake: FakeUseCase): UpdateNotifier => {
    notifier = new UpdateNotifier(fake.useCase, '9.9.9');
    return notifier;
  };

  /** The app is back on screen, as after the installer or its settings closed. */
  const backOnScreen = () => {
    visibility.mockReturnValue('visible');
    document.dispatchEvent(new Event('visibilitychange'));
  };

  /** The notifier with its APK downloaded, a tap away from the installer. */
  const downloaded = async (fake: FakeUseCase): Promise<UpdateNotifier> => {
    const state = make(fake);
    await flush();
    state.download();
    await flush();
    fake.downloads[0].end(WHOLE);
    await flush();
    return state;
  };

  beforeEach(() => {
    visibility = spyVisibility().mockReturnValue('visible');
  });

  afterEach(() => {
    notifier?.dispose();
    vi.restoreAllMocks();
    vi.mocked(toast.error).mockClear();
  });

  it('asks nothing outside the shell, and leaves the row as it was', async () => {
    const fake = new FakeUseCase();
    fake.canCheck.mockReturnValue(false);
    const state = make(fake);

    state.enter();
    await flush();

    expect(state.getState()).toEqual({
      status: 'unsupported',
      version: '9.9.9',
      support: null,
      release: null,
      percent: null,
    });
    expect(fake.installed).not.toHaveBeenCalled();
    expect(fake.check).not.toHaveBeenCalled();
  });

  it('is looking from its first frame, and names no version until the shell said it', async () => {
    const fake = new FakeUseCase();
    const shell = deferred<Result<InstalledVersion>>();
    fake.installed.mockReturnValue(shell.promise);
    fake.check.mockReturnValue(new Promise<Result<UpdateCheck>>(() => undefined));
    const state = make(fake);

    expect(state.getState()).toMatchObject({ status: 'checking', version: null });

    shell.resolve(ok(INSTALLED));
    await flush();

    expect(state.getState()).toMatchObject({ status: 'checking', version: '4.0.0' });
  });

  it('says that a newer version is available, with the release', async () => {
    const state = make(new FakeUseCase().asShell());
    await flush();

    expect(state.getState()).toMatchObject({
      status: 'available',
      release: RELEASE,
      version: '4.0.0',
      support: 'native',
    });
  });

  it('says that the version is the newest, and keeps no release', async () => {
    const fake = new FakeUseCase().asShell();
    fake.check.mockResolvedValue(upToDate());
    const state = make(fake);
    await flush();

    expect(state.getState()).toMatchObject({ status: 'upToDate', release: null, version: '4.0.0' });
  });

  it('keeps the version it read when the look fails, and looks again when asked', async () => {
    const fake = new FakeUseCase().asShell();
    fake.check.mockResolvedValue({ ok: false, failure: new NetworkFailure('timeout') });
    const state = make(fake);
    await flush();
    expect(state.getState()).toMatchObject({
      status: 'checkFailed',
      version: '4.0.0',
      release: null,
    });

    fake.check.mockResolvedValue(available());
    state.retry();
    expect(state.getState().status).toBe('checking');
    await flush();
    expect(state.getState().status).toBe('available');
    expect(fake.check).toHaveBeenCalledTimes(2);
  });

  it('says a reading that failed, with no number, and reads again when asked', async () => {
    const fake = new FakeUseCase().asShell();
    const unreadable: Result<InstalledVersion> = {
      ok: false,
      failure: new NetworkFailure('timed out'),
    };
    fake.installed.mockResolvedValue(unreadable);
    const state = make(fake);
    await flush();

    expect(state.getState()).toMatchObject({
      status: 'checkFailed',
      version: null,
      release: null,
    });
    expect(fake.check).not.toHaveBeenCalled();

    state.retry();
    expect(state.getState().status).toBe('checking');
    await flush();
    expect(state.getState()).toMatchObject({ status: 'checkFailed', version: null });
    expect(fake.check).not.toHaveBeenCalled();

    fake.installed.mockResolvedValue(ok(INSTALLED));
    state.retry();
    await flush();
    expect(state.getState()).toMatchObject({ status: 'available', version: '4.0.0' });
  });

  it('keeps a version it read before when a later reading fails', async () => {
    const fake = new FakeUseCase().asShell();
    const state = make(fake);
    await flush();

    fake.installed.mockResolvedValue({
      ok: false,
      failure: new NetworkFailure('timed out'),
    });
    state.enter();
    await flush();

    expect(state.getState()).toMatchObject({
      status: 'checkFailed',
      version: '4.0.0',
      release: null,
    });
    expect(fake.check).toHaveBeenCalledTimes(1);
  });

  it('looks once while a look the reader asked for runs', async () => {
    const fake = new FakeUseCase().asShell();
    fake.check.mockResolvedValue({ ok: false, failure: new NetworkFailure('timeout') });
    const state = make(fake);
    await flush();

    const answer = deferred<Result<UpdateCheck>>();
    fake.check.mockReturnValue(answer.promise);
    state.retry();
    state.retry();
    await flush();

    expect(fake.check).toHaveBeenCalledTimes(2);
    expect(state.getState().status).toBe('checking');
    answer.resolve(available());
    await flush();
    expect(state.getState().status).toBe('available');
  });

  it('takes a shell that cannot tell its version for 4.0.0, which gets the new version by hand', async () => {
    const fake = new FakeUseCase().asShell();
    fake.installed.mockResolvedValue(ok(MANUAL));
    fake.check.mockResolvedValue({
      ok: true,
      value: { ...MANUAL, release: RELEASE, hasNewVersion: true },
    });
    const state = make(fake);
    await flush();

    expect(state.getState()).toMatchObject({
      status: 'available',
      version: '4.0.0',
      support: 'manual',
    });
  });

  it('looks again when the settings open again, and what the row says stays until the answer', async () => {
    const fake = new FakeUseCase().asShell();
    fake.check.mockResolvedValue(upToDate());
    const state = make(fake);
    await flush();

    const answer = deferred<Result<UpdateCheck>>();
    fake.check.mockReturnValue(answer.promise);
    state.enter();
    expect(state.getState().status).toBe('upToDate');
    await flush();
    expect(fake.check).toHaveBeenCalledTimes(2);
    expect(state.getState().status).toBe('upToDate');

    answer.resolve(available());
    await flush();
    expect(state.getState().status).toBe('available');
  });

  it('keeps a failure on the screen when the settings open again, until the new look answers', async () => {
    const fake = new FakeUseCase().asShell();
    fake.check.mockResolvedValue({ ok: false, failure: new NetworkFailure('timeout') });
    const state = make(fake);
    await flush();

    const answer = deferred<Result<UpdateCheck>>();
    fake.check.mockReturnValue(answer.promise);
    state.enter();
    expect(state.getState().status).toBe('checkFailed');
    await flush();
    expect(fake.check).toHaveBeenCalledTimes(2);

    answer.resolve(upToDate());
    await flush();
    expect(state.getState().status).toBe('upToDate');
  });

  it('asks nothing of GitHub again while a version is on its way', async () => {
    const fake = new FakeUseCase().asShell();
    fake.hangDownloads();
    fake.install.mockResolvedValue({ ok: true, value: false });
    const state = make(fake);
    await flush();
    expect(fake.check).toHaveBeenCalledTimes(1);

    state.download();
    state.enter();
    await flush();
    expect(state.getState().status).toBe('downloading');

    fake.downloads[0].end(NOT_FOUND);
    await flush();
    expect(state.getState().status).toBe('downloadFailed');

    state.enter();
    state.retry();
    await flush();
    expect(state.getState().status).toBe('downloading');

    fake.downloads[1].end(WHOLE);
    await flush();
    expect(state.getState().status).toBe('ready');

    state.enter();
    await state.install();
    expect(state.getState().status).toBe('installFailed');

    state.enter();
    state.retry();
    await flush();
    fake.downloads[2].end(WHOLE);
    await flush();

    expect(fake.check).toHaveBeenCalledTimes(1);
    expect(fake.downloads).toHaveLength(3);
    expect(state.getState().status).toBe('ready');
  });

  it('downloads the release, telling how far it is', async () => {
    const fake = new FakeUseCase().asShell();
    fake.hangDownloads();
    const state = make(fake);
    await flush();

    state.download();

    expect(fake.download).toHaveBeenCalledWith(RELEASE, expect.any(Function));
    expect(state.getState()).toMatchObject({
      status: 'downloading',
      percent: null,
      release: RELEASE,
    });
    fake.downloads[0].tell(45);
    expect(state.getState().percent).toBe(45);

    fake.downloads[0].end(WHOLE);
    await flush();
    expect(state.getState()).toMatchObject({ status: 'ready', percent: null });
  });

  it('installs the file it holds, and stays ready while the system asks the reader', async () => {
    const fake = new FakeUseCase().asShell();
    fake.hangDownloads();
    fake.install.mockResolvedValue({ ok: true, value: true });
    const state = await downloaded(fake);

    await state.install();

    expect(fake.install).toHaveBeenCalledWith('/cache/downloads/keek-news.apk');
    expect(state.getState().status).toBe('ready');
  });

  it('asks for the permission when the app may not install', async () => {
    const fake = new FakeUseCase().asShell();
    fake.hangDownloads();
    fake.canInstall.mockResolvedValue({ ok: true, value: false });
    const state = make(fake);
    await flush();

    state.download();
    fake.downloads[0].end(WHOLE);
    await flush();

    expect(state.getState()).toMatchObject({ status: 'permissionNeeded', release: RELEASE });
  });

  it('comes back to available when the download is cancelled, which is not a failure', async () => {
    const fake = new FakeUseCase().asShell();
    fake.hangDownloads();
    const state = make(fake);
    await flush();

    state.download();
    state.cancel();
    expect(fake.downloads[0].cancel).toHaveBeenCalledTimes(1);
    fake.downloads[0].end({ type: 'cancelled' });
    await flush();

    expect(state.getState()).toMatchObject({ status: 'available', percent: null });
    expect(toast.error).not.toHaveBeenCalled();
  });

  it('says a download that failed, and downloads again when asked', async () => {
    const fake = new FakeUseCase().asShell();
    fake.hangDownloads();
    const state = make(fake);
    await flush();

    state.download();
    fake.downloads[0].end(NOT_FOUND);
    await flush();
    expect(state.getState().status).toBe('downloadFailed');

    state.retry();
    expect(state.getState().status).toBe('downloading');
    expect(fake.downloads).toHaveLength(2);
  });

  it('says an install that could not start, and downloads again when asked', async () => {
    const fake = new FakeUseCase().asShell();
    fake.hangDownloads();
    fake.install.mockResolvedValue({ ok: true, value: false });
    const state = await downloaded(fake);

    await state.install();

    expect(state.getState()).toMatchObject({ status: 'installFailed', release: RELEASE });
    expect(toast.error).not.toHaveBeenCalled();

    state.retry();
    expect(state.getState().status).toBe('downloading');
    expect(fake.downloads).toHaveLength(2);
  });

  it('stays ready when the app is back and the version is not installed yet', async () => {
    const fake = new FakeUseCase().asShell();
    fake.hangDownloads();
    const state = await downloaded(fake);

    backOnScreen();
    await flush();

    expect(state.getState().status).toBe('ready');
    expect(fake.check).toHaveBeenCalledTimes(1);
  });

  it('has nothing pending once the version is installed, and looks when the settings open again', async () => {
    const fake = new FakeUseCase().asShell();
    fake.hangDownloads();
    const state = await downloaded(fake);
    fake.isBehind.mockResolvedValue(false);

    backOnScreen();
    await flush();

    expect(state.getState()).toMatchObject({ status: 'idle', release: null, version: '4.0.0' });
    await state.install();
    expect(fake.install).not.toHaveBeenCalled();

    state.enter();
    expect(state.getState().status).toBe('checking');
  });

  it('reads the permission again when the app is back, without asking GitHub', async () => {
    const fake = new FakeUseCase().asShell();
    fake.hangDownloads();
    fake.canInstall.mockResolvedValue({ ok: true, value: false });
    const state = make(fake);
    await flush();
    state.download();
    fake.downloads[0].end(WHOLE);
    await flush();
    expect(state.getState().status).toBe('permissionNeeded');

    fake.canInstall.mockResolvedValue({ ok: true, value: true });
    backOnScreen();
    await flush();

    expect(state.getState().status).toBe('ready');
    expect(fake.check).toHaveBeenCalledTimes(1);
  });

  it('stays when the app is back and the permission is still missing', async () => {
    const fake = new FakeUseCase().asShell();
    fake.hangDownloads();
    fake.canInstall.mockResolvedValue({ ok: true, value: false });
    const state = make(fake);
    await flush();
    state.download();
    fake.downloads[0].end(WHOLE);
    await flush();

    backOnScreen();
    await flush();

    expect(state.getState().status).toBe('permissionNeeded');
  });

  it('reads nothing when the app is back and nothing is pending', async () => {
    const fake = new FakeUseCase().asShell();
    make(fake);
    await flush();

    backOnScreen();
    await flush();

    expect(fake.isBehind).not.toHaveBeenCalled();
    expect(fake.canInstall).not.toHaveBeenCalled();
  });

  it('opens the settings, and says so when they cannot be opened', async () => {
    const fake = new FakeUseCase().asShell();
    fake.hangDownloads();
    fake.canInstall.mockResolvedValue({ ok: true, value: false });
    const state = make(fake);
    await flush();
    state.download();
    fake.downloads[0].end(WHOLE);
    await flush();

    fake.openInstallSettings.mockResolvedValue({ ok: true, value: true });
    await state.openInstallSettings();
    expect(toast.error).not.toHaveBeenCalled();

    fake.openInstallSettings.mockResolvedValue({
      ok: false,
      failure: new NetworkFailure('no activity'),
    });
    await state.openInstallSettings();

    expect(toast.error).toHaveBeenCalledWith('설정을 열지 못했어요');
    expect(state.getState().status).toBe('permissionNeeded');
  });

  it('lets an answer that lands during a download pass', async () => {
    const fake = new FakeUseCase().asShell();
    fake.hangDownloads();
    const first = deferred<Result<UpdateCheck>>();
    const second = deferred<Result<UpdateCheck>>();
    fake.check.mockReturnValueOnce(first.promise).mockReturnValueOnce(second.promise);
    make(fake);
    first.resolve(available());
    await flush();

    notifier?.enter();
    notifier?.download();
    second.resolve(upToDate());
    await flush();

    expect(notifier?.getState()).toMatchObject({ status: 'downloading', release: RELEASE });
  });

  it('does nothing from a status that does not allow it', () => {
    const fake = new FakeUseCase().asShell();
    fake.hangDownloads();
    const state = make(fake);

    state.download();
    state.cancel();
    state.retry();
    void state.install();
    void state.openInstallSettings();

    expect(fake.downloads).toHaveLength(0);
    expect(fake.install).not.toHaveBeenCalled();
    expect(fake.openInstallSettings).not.toHaveBeenCalled();
  });

  it('changes nothing once disposed', async () => {
    const fake = new FakeUseCase().asShell();
    const state = make(fake);
    await flush();
    state.dispose();
    const before = state.getState();

    backOnScreen();
    state.enter();
    await flush();

    expect(state.getState()).toBe(before);
    expect(fake.check).toHaveBeenCalledTimes(1);
    expect(fake.isBehind).not.toHaveBeenCalled();
  });
});
