// @vitest-environment jsdom
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { BlockedImage } from '../../src/model/blocked_image';
import { ServerFailure } from '../../src/model/failures';
import type { Result } from '../../src/model/result';
import { StateNotifier, useNotifierState } from '../../src/provider/state_notifier';

const toast = { success: vi.fn(), error: vi.fn() };

/** What unblocking answers. A test makes it answer a failure. */
const unblock = vi.fn<(url: string) => Promise<Result<void>>>();

const A = 'https://example.com/uploads/a.jpg';
const B = 'https://example.com/uploads/b.jpg';

const blocked = (url: string, hoursAgo: number): BlockedImage => ({
  url,
  blockedAt: new Date(2026, 10, 28, 12 - hoursAgo),
});

/** The images the screen sees: the test fills the list, and what the screen does changes it. */
class Blocklist extends StateNotifier<BlockedImage[]> {
  constructor(images: BlockedImage[]) {
    super(images);
  }

  remove(url: string): void {
    this.state = this.state.filter((image) => image.url !== url);
  }
}

let BlockedImagesView: typeof import('../../src/pages/blocked_images_view').BlockedImagesView;

/** The screen over `images`, which a test fills. */
async function loadBlockedImages(images: BlockedImage[]): Promise<void> {
  vi.resetModules();
  toast.success.mockReset();
  toast.error.mockReset();
  unblock.mockReset();
  const blocklist = new Blocklist(images);
  // A write that works reaches the list the way the repo's change stream does.
  unblock.mockImplementation(async (url) => {
    blocklist.remove(url);
    return { ok: true, value: undefined };
  });
  vi.doMock('../../src/provider/blocked_images_provider', () => ({
    blockedImagesNotifier: () => ({ unblock }),
    useBlockedImages: () => useNotifierState(blocklist),
  }));
  vi.doMock('sonner', () => ({ toast }));
  ({ BlockedImagesView } = await import('../../src/pages/blocked_images_view'));
}

const unblockButtons = (): HTMLElement[] => screen.getAllByRole('button', { name: '차단 해제' });

describe('BlockedImagesView', () => {
  beforeEach(() => {
    vi.setSystemTime(new Date(2026, 10, 28, 12));
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('has a title and a way back', async () => {
    await loadBlockedImages([]);
    const onBack = vi.fn();

    render(<BlockedImagesView onBack={onBack} />);
    fireEvent.click(screen.getByRole('button', { name: '뒤로' }));

    expect(screen.getByRole('heading', { level: 1, name: '차단된 이미지' })).toBeTruthy();
    expect(onBack).toHaveBeenCalledTimes(1);
  });

  it('says nothing is blocked, and where blocking is done', async () => {
    await loadBlockedImages([]);
    const { container } = render(<BlockedImagesView onBack={() => undefined} />);

    expect(screen.getByText('차단된 이미지가 없어요')).toBeTruthy();
    expect(screen.getByText('이미지를 열어 메뉴에서 차단할 수 있어요')).toBeTruthy();
    const icon = container.querySelector('[role="status"] svg');
    expect(icon?.getAttribute('class')).toContain('lucide-image-off');
    expect(icon?.getAttribute('aria-hidden')).toBe('true');
    expect(screen.queryByRole('button', { name: '차단 해제' })).toBeNull();
  });

  it('lists every blocked image with when it was blocked and its address, in the order of the list', async () => {
    await loadBlockedImages([blocked(A, 1), blocked(B, 5)]);
    const { container } = render(<BlockedImagesView onBack={() => undefined} />);

    expect([...container.querySelectorAll('p')].map((line) => line.textContent)).toEqual([
      '1시간 전',
      A,
      '5시간 전',
      B,
    ]);
    expect(unblockButtons()).toHaveLength(2);
  });

  it('offers nothing that opens a picture: the viewer is not wired yet', async () => {
    await loadBlockedImages([blocked(A, 1)]);
    render(<BlockedImagesView onBack={() => undefined} />);

    // A thumbnail that cannot open anything must not look as if it could.
    expect(screen.queryByRole('button', { name: '전체화면으로 보기' })).toBeNull();
    expect(
      screen.getAllByRole('button').map((button) => button.getAttribute('aria-label'))
    ).toEqual(['뒤로', '차단 해제']);
  });

  it('unblocks an image when asked, which leaves the list, and says so', async () => {
    await loadBlockedImages([blocked(A, 1), blocked(B, 5)]);
    render(<BlockedImagesView onBack={() => undefined} />);

    fireEvent.click(unblockButtons()[0]);
    await waitFor(() => expect(screen.queryByText(A)).toBeNull());

    expect(unblock).toHaveBeenCalledExactlyOnceWith(A);
    expect(screen.getByText(B)).toBeTruthy();
    expect(unblockButtons()).toHaveLength(1);
    expect(toast.success).toHaveBeenCalledExactlyOnceWith('차단을 해제했어요');
    expect(toast.error).not.toHaveBeenCalled();
  });

  it('says so, and keeps the image listed, when unblocking did not work', async () => {
    await loadBlockedImages([blocked(A, 1)]);
    unblock.mockResolvedValueOnce({ ok: false, failure: new ServerFailure('storage') });
    render(<BlockedImagesView onBack={() => undefined} />);

    fireEvent.click(unblockButtons()[0]);
    await waitFor(() =>
      expect(toast.error).toHaveBeenCalledExactlyOnceWith('차단 해제에 실패했어요')
    );

    expect(unblock).toHaveBeenCalledExactlyOnceWith(A);
    expect(screen.getByText(A)).toBeTruthy();
    expect(unblockButtons()).toHaveLength(1);
    expect(toast.success).not.toHaveBeenCalled();
  });

  it('shows that nothing is blocked once the last image is unblocked', async () => {
    await loadBlockedImages([blocked(A, 1)]);
    render(<BlockedImagesView onBack={() => undefined} />);

    fireEvent.click(unblockButtons()[0]);

    expect(await screen.findByText('차단된 이미지가 없어요')).toBeTruthy();
    expect(screen.queryByText(A)).toBeNull();
    expect(toast.success).toHaveBeenCalledExactlyOnceWith('차단을 해제했어요');
  });
});
