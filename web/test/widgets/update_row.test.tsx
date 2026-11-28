// @vitest-environment jsdom
import { fireEvent, render, screen, within } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import type { AppRelease, UpdateState, UpdateStatus } from '../../src/model/app_update';
import { UpdateRow } from '../../src/widgets/update_row';

const RELEASE: AppRelease = {
  tag: 'v4.1.0',
  version: '4.1.0',
  pageUrl: 'https://github.com/dev-hann/keek-news/releases/tag/v4.1.0',
  apkUrl: 'https://github.com/dev-hann/keek-news/releases/download/v4.1.0/keek-news.apk',
};

const state = (change: Partial<UpdateState>): UpdateState => ({
  status: 'upToDate',
  version: '4.0.0',
  support: 'native',
  release: null,
  percent: null,
  ...change,
});

function taps() {
  return {
    onDownload: vi.fn(),
    onCancel: vi.fn(),
    onRetry: vi.fn(),
    onInstall: vi.fn(),
    onOpenInstallSettings: vi.fn(),
  };
}

function show(change: Partial<UpdateState>) {
  const handlers = taps();
  const view = render(<UpdateRow state={state(change)} {...handlers} />);
  return { ...view, handlers };
}

/** The line under the title, as one reads it. */
const subtitle = (): string => screen.getByText('버전').nextElementSibling?.textContent ?? '';

describe('UpdateRow', () => {
  it('outside the shell: the version of the build, and nothing else', () => {
    show({ status: 'unsupported', version: '9.9.9', support: null });

    expect(screen.getByText('v9.9.9')).toBeTruthy();
    expect(screen.queryByRole('button')).toBeNull();
    expect(screen.queryByRole('link')).toBeNull();
    expect(screen.queryByRole('status')).toBeNull();
    expect(screen.queryByRole('alert')).toBeNull();
  });

  it('before the shell said what is installed: the title, and an empty second line', () => {
    const { container } = show({ status: 'checking', version: null });

    expect(screen.getByText('버전')).toBeTruthy();
    expect(subtitle()).toBe('');
    expect(container.querySelector('.animate-spin')).toBeNull();
    expect(screen.queryByRole('button')).toBeNull();
    expect(screen.queryByRole('status')).toBeNull();
    expect(screen.queryByRole('link')).toBeNull();
  });

  it('a version that was installed meanwhile, and nothing said about a newer one', () => {
    show({ status: 'idle', version: '4.1.0' });

    expect(subtitle()).toBe('v4.1.0');
    expect(screen.queryByRole('status')).toBeNull();
  });

  it('looking for a new version', () => {
    const { container } = show({ status: 'checking' });

    expect(subtitle()).toBe('v4.0.0 · 확인 중…');
    expect(screen.getByRole('status').textContent).toBe('확인 중…');
    expect(container.querySelector('.animate-spin')).not.toBeNull();
    expect(screen.queryByRole('button')).toBeNull();
  });

  it('the version is the newest', () => {
    show({ status: 'upToDate' });

    expect(subtitle()).toBe('v4.0.0 · 최신 버전');
    expect(screen.getByRole('status').textContent).toBe('최신 버전');
  });

  it('a newer version: one button to get it, and the line to its notes', () => {
    const { handlers } = show({ status: 'available', release: RELEASE });

    expect(subtitle()).toBe('v4.0.0 · v4.1.0 사용 가능');
    expect(screen.getByRole('status').textContent).toBe('v4.1.0 사용 가능');
    fireEvent.click(screen.getByRole('button', { name: '업데이트' }));
    expect(handlers.onDownload).toHaveBeenCalledTimes(1);

    const notes = screen.getByRole('link', { name: '업데이트 내용' });
    expect(notes).toHaveProperty('href', RELEASE.pageUrl);
    expect(notes).toHaveProperty('target', '_blank');
    expect(notes).toHaveProperty('rel', 'noopener noreferrer');
  });

  it('a shell that cannot download sends the reader to the Release page instead', () => {
    const { handlers } = show({ status: 'available', support: 'manual', release: RELEASE });

    const getIt = screen.getByRole('link', { name: 'GitHub에서 받기' });
    expect(getIt).toHaveProperty('href', RELEASE.pageUrl);
    expect(getIt).toHaveProperty('target', '_blank');
    expect(screen.queryByRole('button')).toBeNull();
    expect(screen.queryByRole('link', { name: '업데이트 내용' })).toBeNull();
    expect(handlers.onDownload).not.toHaveBeenCalled();
  });

  it('downloading: the words are announced, the percent is shown next to them', () => {
    const { handlers } = show({ status: 'downloading', release: RELEASE, percent: 45 });

    expect(subtitle()).toBe('v4.0.0 · 다운로드 중 45%');
    const said = screen.getByRole('status');
    expect(said.textContent).toBe('다운로드 중');
    expect(within(said).queryByText('45%')).toBeNull();
    expect(screen.getByText('45%')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: '취소' }));
    expect(handlers.onCancel).toHaveBeenCalledTimes(1);
    expect(screen.getByRole('link', { name: '업데이트 내용' })).toBeTruthy();
  });

  it('downloading a file whose size is not known', () => {
    show({ status: 'downloading', release: RELEASE, percent: null });

    expect(subtitle()).toBe('v4.0.0 · 다운로드 중…');
    expect(screen.queryByText(/%/)).toBeNull();
  });

  it('a download that failed: said as an alert, with a way to try again', () => {
    const { container, handlers } = show({ status: 'downloadFailed', release: RELEASE });

    expect(subtitle()).toBe('v4.0.0 · 다운로드 실패');
    expect(screen.getByRole('alert').textContent).toBe('다운로드 실패');
    expect(container.querySelector('.lucide-circle-alert')).not.toBeNull();
    fireEvent.click(screen.getByRole('button', { name: '다시 시도' }));
    expect(handlers.onRetry).toHaveBeenCalledTimes(1);
    expect(screen.getByRole('link', { name: '업데이트 내용' })).toBeTruthy();
  });

  it('downloaded: the installer is a tap away', () => {
    const { container, handlers } = show({ status: 'ready', release: RELEASE });

    expect(subtitle()).toBe('v4.0.0 · 다운로드 완료');
    expect(container.querySelector('.lucide-info')).not.toBeNull();
    fireEvent.click(screen.getByRole('button', { name: '설치' }));
    expect(handlers.onInstall).toHaveBeenCalledTimes(1);
    expect(screen.getByRole('link', { name: '업데이트 내용' })).toBeTruthy();
  });

  it('the app may not install yet: the settings are a tap away', () => {
    const { handlers } = show({ status: 'permissionNeeded', release: RELEASE });

    expect(subtitle()).toBe('v4.0.0 · 설치 권한 필요');
    expect(screen.getByRole('status').textContent).toBe('설치 권한 필요');
    fireEvent.click(screen.getByRole('button', { name: '설정 열기' }));
    expect(handlers.onOpenInstallSettings).toHaveBeenCalledTimes(1);
  });

  it('an install that could not start: said as an alert, with a way to try again', () => {
    const { handlers } = show({ status: 'installFailed', release: RELEASE });

    expect(subtitle()).toBe('v4.0.0 · 설치 실패');
    expect(screen.getByRole('alert').textContent).toBe('설치 실패');
    fireEvent.click(screen.getByRole('button', { name: '다시 시도' }));
    expect(handlers.onRetry).toHaveBeenCalledTimes(1);
    expect(screen.getByRole('link', { name: '업데이트 내용' })).toBeTruthy();
  });

  it('a check that failed: said as an alert, with a way to try again and no notes to show', () => {
    const { container, handlers } = show({ status: 'checkFailed' });

    expect(subtitle()).toBe('v4.0.0 · 확인 실패');
    expect(screen.getByRole('alert').textContent).toBe('확인 실패');
    expect(container.querySelector('.lucide-circle-alert')).not.toBeNull();
    fireEvent.click(screen.getByRole('button', { name: '다시 시도' }));
    expect(handlers.onRetry).toHaveBeenCalledTimes(1);
    expect(screen.queryByRole('link')).toBeNull();
  });

  it('a check that failed before the version was read: the words alone, and never another number', () => {
    show({ status: 'checkFailed', version: null });

    expect(subtitle()).toBe('확인 실패');
    expect(screen.queryByRole('button', { name: '업데이트' })).toBeNull();
    expect(screen.getByRole('button', { name: '다시 시도' })).toBeTruthy();
  });

  it('is a row that carries controls, not a control itself, and every target is 44px tall', () => {
    const statuses: UpdateStatus[] = [
      'unsupported',
      'idle',
      'checking',
      'upToDate',
      'available',
      'downloading',
      'downloadFailed',
      'ready',
      'permissionNeeded',
      'installFailed',
      'checkFailed',
    ];

    for (const status of statuses) {
      const { container, unmount } = show({ status, release: RELEASE });
      const row = container.firstElementChild;
      expect(row?.tagName).toBe('DIV');
      for (const control of screen.queryAllByRole('button')) {
        expect(control.className).toMatch(/\bh-11\b/);
      }
      for (const link of screen.queryAllByRole('link')) {
        expect(link.className).toMatch(/\bmin-h-11\b/);
      }
      unmount();
    }
  });

  it('the icon is not announced: the row is read by its words', () => {
    show({ status: 'ready', release: RELEASE });
    for (const icon of document.querySelectorAll('svg')) {
      expect(icon).toHaveProperty('ariaHidden', 'true');
    }
  });

  it('is one button across the statuses, so the focus stays on it', () => {
    const handlers = taps();
    const view = render(
      <UpdateRow state={state({ status: 'available', release: RELEASE })} {...handlers} />
    );
    const button = screen.getByRole('button', { name: '업데이트' });
    button.focus();

    view.rerender(
      <UpdateRow
        state={state({ status: 'downloading', release: RELEASE, percent: 10 })}
        {...handlers}
      />
    );
    expect(screen.getByRole('button', { name: '취소' })).toBe(button);
    expect(document.activeElement).toBe(button);

    view.rerender(
      <UpdateRow state={state({ status: 'downloadFailed', release: RELEASE })} {...handlers} />
    );
    expect(screen.getByRole('button', { name: '다시 시도' })).toBe(button);
    expect(document.activeElement).toBe(button);
  });

  it('says a failure in a new element, and takes it away in one that is announced again', () => {
    const handlers = taps();
    const view = render(
      <UpdateRow
        state={state({ status: 'downloading', release: RELEASE, percent: 10 })}
        {...handlers}
      />
    );
    const looking = screen.getByRole('status');

    view.rerender(
      <UpdateRow state={state({ status: 'downloadFailed', release: RELEASE })} {...handlers} />
    );
    expect(screen.getByRole('alert')).not.toBe(looking);

    view.rerender(
      <UpdateRow
        state={state({ status: 'downloading', release: RELEASE, percent: 10 })}
        {...handlers}
      />
    );
    expect(screen.getByRole('status')).not.toBe(looking);
  });
});
