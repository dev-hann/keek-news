import { beforeEach, describe, expect, it, vi } from 'vitest';
import { imageTarget, videoTarget } from '../../src/model/media_target';
import type { MediaSaveRepo } from '../../src/repository/media_save/media_save_repo';
import { SaveMediaUseCase } from '../../src/use_case/save_media_use_case';

function mockRepo() {
  return {
    saveImage: vi.fn<MediaSaveRepo['saveImage']>(),
    saveVideo: vi.fn<MediaSaveRepo['saveVideo']>(),
    share: vi.fn<MediaSaveRepo['share']>(),
  } satisfies MediaSaveRepo;
}

describe('SaveMediaUseCase', () => {
  let repo: ReturnType<typeof mockRepo>;
  let useCase: SaveMediaUseCase;

  beforeEach(() => {
    repo = mockRepo();
    useCase = new SaveMediaUseCase(repo);
  });

  it('delegates image targets to saveImage', async () => {
    repo.saveImage.mockResolvedValue({ ok: true });

    const result = await useCase.call(imageTarget('https://x/a.jpg'));

    expect(result).toStrictEqual({ ok: true });
    expect(repo.saveImage).toHaveBeenCalledExactlyOnceWith('https://x/a.jpg');
    expect(repo.saveVideo).not.toHaveBeenCalled();
  });

  it('delegates video targets to saveVideo', async () => {
    repo.saveVideo.mockResolvedValue({ ok: true });

    const result = await useCase.call(videoTarget({ type: 'video', url: 'https://x/v.mp4' }));

    expect(result).toStrictEqual({ ok: true });
    expect(repo.saveVideo).toHaveBeenCalledExactlyOnceWith('https://x/v.mp4');
  });

  it('external embeds return Left(unexpected) without touching the repo', async () => {
    const result = await useCase.call(videoTarget({ type: 'video', url: 'https://youtu.be/x' }));

    expect(result).toStrictEqual({ ok: false, failure: { type: 'unexpected' } });
    expect(repo.saveImage).not.toHaveBeenCalled();
    expect(repo.saveVideo).not.toHaveBeenCalled();
  });
});
