import { beforeEach, describe, expect, it, vi } from 'vitest';
import { imageTarget } from '../../src/model/media_target';
import type { MediaSaveRepo } from '../../src/repository/media_save/media_save_repo';
import { ShareMediaUseCase } from '../../src/use_case/share_media_use_case';

function mockRepo() {
  return {
    saveImage: vi.fn<MediaSaveRepo['saveImage']>(),
    saveVideo: vi.fn<MediaSaveRepo['saveVideo']>(),
    share: vi.fn<MediaSaveRepo['share']>(),
  } satisfies MediaSaveRepo;
}

describe('ShareMediaUseCase', () => {
  let repo: ReturnType<typeof mockRepo>;
  let useCase: ShareMediaUseCase;

  beforeEach(() => {
    repo = mockRepo();
    useCase = new ShareMediaUseCase(repo);
  });

  it('delegates to repo.share', async () => {
    const target = imageTarget('https://x/a.jpg');
    repo.share.mockResolvedValue({ ok: true });

    const result = await useCase.call(target);

    expect(result).toStrictEqual({ ok: true });
    expect(repo.share).toHaveBeenCalledExactlyOnceWith(target);
  });
});
