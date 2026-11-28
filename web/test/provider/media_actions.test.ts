import { beforeEach, describe, expect, it, vi } from 'vitest';
import { imageTarget, videoTarget } from '../../src/model/media_target';

const toast = { success: vi.fn(), error: vi.fn() };
const copyText = vi.fn();
const blocklist = { block: vi.fn(), unblock: vi.fn() };
const save = { call: vi.fn() };
const share = { call: vi.fn() };

let actions: typeof import('../../src/provider/media_actions');

beforeEach(async () => {
  vi.resetModules();
  vi.clearAllMocks();
  vi.doMock('sonner', () => ({ toast }));
  vi.doMock('../../src/utils/clipboard', () => ({ copyText }));
  vi.doMock('../../src/provider/blocked_images_provider', () => ({
    blockedImagesNotifier: () => blocklist,
  }));
  vi.doMock('../../src/service/service_locator', () => ({
    saveMediaUseCase: () => save,
    shareMediaUseCase: () => share,
  }));
  actions = await import('../../src/provider/media_actions');
});

const ok = () => ({ ok: true as const, value: undefined });
const failed = () => ({ ok: false as const, failure: new Error('quota') });

describe('copyMediaUrl', () => {
  it('copies the address of the picture, and says so', async () => {
    copyText.mockResolvedValue(true);

    await actions.copyMediaUrl(imageTarget('https://e.com/a.jpg'));

    expect(copyText).toHaveBeenCalledWith('https://e.com/a.jpg');
    expect(toast.success).toHaveBeenCalledWith('링크를 복사했어요');
  });

  it('copies the address of a video, of any kind', async () => {
    copyText.mockResolvedValue(true);

    await actions.copyMediaUrl(videoTarget({ type: 'video', url: 'https://youtu.be/abc' }));

    expect(copyText).toHaveBeenCalledWith('https://youtu.be/abc');
  });

  it('says so when the copy did not work', async () => {
    copyText.mockResolvedValue(false);

    await actions.copyMediaUrl(imageTarget('https://e.com/a.jpg'));

    expect(toast.error).toHaveBeenCalledWith('링크를 복사하지 못했습니다');
  });
});

describe('blockImage', () => {
  it('blocks the image and offers to take it back', async () => {
    blocklist.block.mockResolvedValue(ok());

    await actions.blockImage('https://e.com/a.jpg');

    expect(blocklist.block).toHaveBeenCalledWith('https://e.com/a.jpg');
    expect(toast.success).toHaveBeenCalledTimes(1);
    const [message, options] = toast.success.mock.calls[0];
    expect(message).toBe('이미지를 차단했어요');
    expect(options.action.label).toBe('취소');

    blocklist.unblock.mockResolvedValue(ok());
    options.action.onClick();
    await Promise.resolve();

    expect(blocklist.unblock).toHaveBeenCalledWith('https://e.com/a.jpg');
  });

  it('says so when the block did not work, and offers nothing to take back', async () => {
    blocklist.block.mockResolvedValue(failed());

    await actions.blockImage('https://e.com/a.jpg');

    expect(toast.error).toHaveBeenCalledWith('차단하지 못했어요');
    expect(toast.success).not.toHaveBeenCalled();
  });
});

describe('unblockImage', () => {
  it('shows the image again, and says so', async () => {
    blocklist.unblock.mockResolvedValue(ok());

    await actions.unblockImage('https://e.com/a.jpg');

    expect(toast.success).toHaveBeenCalledWith('차단을 해제했어요');
  });

  it('says so when it did not work', async () => {
    blocklist.unblock.mockResolvedValue(failed());

    await actions.unblockImage('https://e.com/a.jpg');

    expect(toast.error).toHaveBeenCalledWith('차단 해제에 실패했어요');
  });

  describe('saveMedia', () => {
    it('saves through the use case, says so, and answers the sheet with what came of it', async () => {
      save.call.mockResolvedValue(ok());

      await expect(actions.saveMedia(imageTarget('https://e.com/a.jpg'))).resolves.toEqual(ok());

      expect(save.call).toHaveBeenCalledWith(imageTarget('https://e.com/a.jpg'));
      expect(toast.success).toHaveBeenCalledWith('저장했어요');
      expect(toast.error).not.toHaveBeenCalled();
    });

    it('says what to do about a permission the app lacks', async () => {
      save.call.mockResolvedValue({
        ok: false,
        failure: { type: 'permission' },
      });

      await actions.saveMedia(imageTarget('https://e.com/a.jpg'));

      expect(toast.error).toHaveBeenCalledWith(
        '갤러리 접근 권한이 필요해요. 시스템 설정에서 허용해주세요'
      );
      expect(toast.success).not.toHaveBeenCalled();
    });

    it('says nothing about any other failure: the sheet shows it in its row', async () => {
      save.call.mockResolvedValue({ ok: false, failure: { type: 'network' } });

      await actions.saveMedia(imageTarget('https://e.com/a.jpg'));

      expect(toast.error).not.toHaveBeenCalled();
      expect(toast.success).not.toHaveBeenCalled();
    });
  });

  describe('shareMedia', () => {
    it('shares through the use case, and says nothing itself', async () => {
      share.call.mockResolvedValue(ok());

      await expect(actions.shareMedia(imageTarget('https://e.com/a.jpg'))).resolves.toEqual(ok());

      expect(share.call).toHaveBeenCalledTimes(1);
      expect(toast.success).not.toHaveBeenCalled();
      expect(toast.error).not.toHaveBeenCalled();
    });
  });
});
