// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen, within } from '@testing-library/react';
import { useEffect, useState } from 'react';
import { afterEach, beforeEach, describe, expect, it, vi, type Mock } from 'vitest';
import type { MediaSaveFailureType, MediaSaveResult } from '../../src/model/media_save_failure';
import { imageTarget, videoTarget, type MediaTarget } from '../../src/model/media_target';
import { MediaActionSheet } from '../../src/widgets/media_action_sheet';

/** The state of the page's own entry, to tell it from the overlay's. */
const HOME = { page: 'home' };

const picture = imageTarget('https://e.com/a.jpg');
const clip: MediaTarget = { url: 'https://e.com/v.mp4', kind: 'video' };
/** A video from outside the community: it can only be shared as an address. */
const embed = videoTarget({ type: 'video', url: 'https://youtu.be/abc' });

const saved: MediaSaveResult = { ok: true };
const failedWith = (type: MediaSaveFailureType): MediaSaveResult => ({
  ok: false,
  failure: { type },
});

interface Actions {
  onCopy?: (target: MediaTarget) => void;
  onBlock?: (target: MediaTarget) => void;
  onSave?: (target: MediaTarget) => Promise<MediaSaveResult>;
  onShare?: (target: MediaTarget) => Promise<MediaSaveResult>;
}

/** What a page hands the sheet when it can do everything, as mocks the test can read. */
type Mocks = { [K in keyof Actions]-?: Mock<NonNullable<Actions[K]>> };

const everything = (): Mocks => ({
  onCopy: vi.fn(),
  onBlock: vi.fn(),
  onSave: vi.fn(async () => saved),
  onShare: vi.fn(async () => saved),
});

/** A page as the app shows one: it keeps the target, and clears it when the sheet asks to be closed. */
function Page({
  first,
  onClosed,
  actions = {},
}: {
  first: MediaTarget | null;
  onClosed: () => void;
  actions?: Actions;
}) {
  const [target, setTarget] = useState<MediaTarget | null>(first);
  return (
    <MediaActionSheet
      target={target}
      open
      onClose={() => {
        setTarget(null);
        onClosed();
      }}
      onCopy={() => undefined}
      {...actions}
    />
  );
}

/** A page whose target the test can change while the sheet is open. */
let retarget: (target: MediaTarget) => void = () => undefined;
function Retargetable({
  onClosed,
  onSave,
}: {
  onClosed: () => void;
  onSave: NonNullable<Actions['onSave']>;
}) {
  const [target, setTarget] = useState<MediaTarget | null>(picture);
  useEffect(() => {
    retarget = (next) => setTarget(next);
  });
  return (
    <MediaActionSheet
      target={target}
      open
      onClose={() => {
        setTarget(null);
        onClosed();
      }}
      onCopy={() => undefined}
      onSave={onSave}
    />
  );
}

/** A promise the test settles itself, as the app does once a save or a share has ended. */
function pending(): { promise: Promise<MediaSaveResult>; end: (result: MediaSaveResult) => void } {
  let end: (result: MediaSaveResult) => void = () => undefined;
  const promise = new Promise<MediaSaveResult>((resolve) => {
    end = resolve;
  });
  return { promise, end };
}

/** jsdom leaves a history entry a task or two later: one such task. */
async function tick(): Promise<void> {
  await act(async () => {
    await new Promise((resolve) => setTimeout(resolve, 0));
  });
}

async function until(done: () => boolean): Promise<void> {
  for (let i = 0; i < 10 && !done(); i++) await tick();
}

/** Outlasts whatever traversal a closing asked for. */
async function settle(): Promise<void> {
  for (let i = 0; i < 3; i++) await tick();
}

/** The page shown is the last entry: a push drops what a test before left in front of it. */
function startAtHome(): void {
  window.history.pushState(HOME, '', '/');
}

function sheet(): HTMLElement {
  return screen.getByRole('dialog');
}

function row(name: string): HTMLElement {
  return within(sheet()).getByRole('button', { name });
}

const names = (): (string | null)[] =>
  within(sheet())
    .getAllByRole('button')
    .map((button) => button.getAttribute('aria-label') ?? button.textContent);

/** Closes the sheet from its own UI, and waits until the page has been told so. */
async function closeByEsc(onClosed: ReturnType<typeof vi.fn>): Promise<void> {
  fireEvent.keyDown(document, { key: 'Escape' });
  await until(() => onClosed.mock.calls.length > 0);
}

describe('MediaActionSheet', () => {
  beforeEach(startAtHome);

  afterEach(async () => {
    // Nothing of this test may traverse the history in the next one.
    cleanup();
    await settle();
    startAtHome();
    retarget = () => undefined;
  });

  it('shows nothing while there is no target, and puts nothing on the history', () => {
    const before = window.history.length;
    const onClosed = vi.fn();
    render(<Page first={null} onClosed={onClosed} actions={everything()} />);

    expect(screen.queryByRole('dialog')).toBeNull();
    expect(window.history.length).toBe(before);
    expect(document.body.style.overflow).toBe('');
  });

  it('shows nothing while it is not open, whatever the target', () => {
    render(
      <MediaActionSheet
        target={picture}
        open={false}
        onClose={() => undefined}
        onCopy={() => undefined}
      />
    );

    expect(screen.queryByRole('dialog')).toBeNull();
  });

  it('is the media menu: a sheet as high as its rows, titled by no heading', () => {
    render(<Page first={picture} onClosed={() => undefined} actions={everything()} />);

    expect(sheet().getAttribute('aria-label')).toBe('미디어 메뉴');
    expect(sheet().getAttribute('aria-modal')).toBe('true');
    expect(within(sheet()).queryByRole('heading')).toBeNull();
    expect(sheet().className).toContain('max-h-[85dvh]');
    expect(within(sheet()).getByRole('button', { name: '닫기' })).toBeTruthy();
  });

  it.each([
    ['a picture', picture],
    ['a video', clip],
    ['an embed', embed],
  ] as const)('URL 복사 is there for %s, and copies the address of the media', (_kind, target) => {
    const onClosed = vi.fn();
    const onCopy = vi.fn();
    render(<Page first={target} onClosed={onClosed} actions={{ onCopy }} />);

    fireEvent.click(row('URL 복사'));

    expect(onCopy).toHaveBeenCalledTimes(1);
    expect(onCopy).toHaveBeenCalledWith(target);
    expect(onCopy.mock.calls[0][0].url).toBe(target.url);
    expect(onClosed).toHaveBeenCalledTimes(1);
    expect(screen.queryByRole('dialog')).toBeNull();
  });

  it('runs the action first, and closes after it', () => {
    const onClosed = vi.fn();
    const onCopy = vi.fn();
    render(<Page first={picture} onClosed={onClosed} actions={{ onCopy }} />);

    fireEvent.click(row('URL 복사'));

    expect(onCopy.mock.invocationCallOrder[0]).toBeLessThan(onClosed.mock.invocationCallOrder[0]);
  });

  it('이미지 차단 is there for an image, as the action that changes something: it blocks, then closes', () => {
    const onClosed = vi.fn();
    const actions = everything();
    render(<Page first={picture} onClosed={onClosed} actions={actions} />);

    const block = row('이미지 차단');
    expect(block.className).toContain('text-destructive');
    expect(block.querySelector('svg[aria-hidden="true"]')).not.toBeNull();
    expect(within(sheet()).queryByRole('alert')).toBeNull();

    fireEvent.click(block);

    expect(actions.onBlock).toHaveBeenCalledWith(picture);
    expect(actions.onBlock.mock.invocationCallOrder[0]).toBeLessThan(
      onClosed.mock.invocationCallOrder[0]
    );
    expect(onClosed).toHaveBeenCalledTimes(1);
  });

  it.each([
    ['a video', clip],
    ['an embed', embed],
  ] as const)('offers no 이미지 차단 for %s, though the page can block', (_kind, target) => {
    render(<Page first={target} onClosed={() => undefined} actions={everything()} />);

    expect(within(sheet()).queryByRole('button', { name: '이미지 차단' })).toBeNull();
    expect(row('URL 복사')).toBeTruthy();
  });

  it('offers no 이미지 차단 where the page cannot block', () => {
    render(<Page first={picture} onClosed={() => undefined} actions={{ onCopy: vi.fn() }} />);

    expect(within(sheet()).queryByRole('button', { name: '이미지 차단' })).toBeNull();
    expect(names()).toEqual(['닫기', 'URL 복사']);
  });

  it('갤러리에 저장 is there for a picture and for a video, each with its icon', () => {
    const forPicture = everything();
    const { unmount } = render(
      <Page first={picture} onClosed={() => undefined} actions={forPicture} />
    );
    expect(row('갤러리에 저장').querySelector('svg')?.getAttribute('class')).toContain(
      'lucide-image-down'
    );
    unmount();
    cleanup();

    render(<Page first={clip} onClosed={() => undefined} actions={everything()} />);
    expect(row('갤러리에 저장').querySelector('svg')?.getAttribute('class')).toContain(
      'lucide-download'
    );
  });

  it('offers no 갤러리에 저장 for an embed from outside, though the page can save', () => {
    render(<Page first={embed} onClosed={() => undefined} actions={everything()} />);

    expect(within(sheet()).queryByRole('button', { name: '갤러리에 저장' })).toBeNull();
    expect(row('공유')).toBeTruthy();
  });

  it('offers no 갤러리에 저장 where the page cannot save', () => {
    render(<Page first={picture} onClosed={() => undefined} actions={{ onCopy: vi.fn() }} />);

    expect(within(sheet()).queryByRole('button', { name: '갤러리에 저장' })).toBeNull();
  });

  it.each([
    ['a picture', picture],
    ['a video', clip],
    ['an embed', embed],
  ] as const)('공유 is there for %s', (_kind, target) => {
    render(<Page first={target} onClosed={() => undefined} actions={everything()} />);

    const share = row('공유');
    expect(share.querySelector('svg')?.getAttribute('class')).toContain('lucide-share-2');
  });

  it('offers no 공유 where the page cannot share', () => {
    render(<Page first={picture} onClosed={() => undefined} actions={{ onCopy: vi.fn() }} />);

    expect(within(sheet()).queryByRole('button', { name: '공유' })).toBeNull();
  });

  it('names its rows in Korean, in the order of the Flutter sheet, with a line between two', () => {
    render(<Page first={picture} onClosed={() => undefined} actions={everything()} />);

    expect(names()).toEqual(['닫기', '갤러리에 저장', '공유', 'URL 복사', '이미지 차단']);
    expect(within(sheet()).getAllByText('갤러리에 저장')).toHaveLength(1);
    expect(within(sheet()).getAllByText('공유')).toHaveLength(1);
    expect(within(sheet()).getAllByText('URL 복사')).toHaveLength(1);
    expect(within(sheet()).getAllByText('이미지 차단')).toHaveLength(1);
    expect(sheet().querySelectorAll('[data-slot="separator"]')).toHaveLength(4);
  });

  it('a row is at least 44px high, and is named by what it says', () => {
    render(<Page first={picture} onClosed={() => undefined} actions={everything()} />);

    for (const name of ['갤러리에 저장', '공유', 'URL 복사', '이미지 차단']) {
      // 56px, as the rows of the Flutter sheet, and not the 32px of the button they are made of.
      expect(row(name).className).toContain('h-14');
      expect(row(name).className).not.toContain('h-8');
      expect(row(name).textContent).toBe(name);
      expect(row(name).querySelector('svg')?.getAttribute('aria-hidden')).toBe('true');
    }
  });

  describe('갤러리에 저장', () => {
    it('is a status and not a button while it saves; a second tap does nothing; the sheet closes once it is saved', async () => {
      const onClosed = vi.fn();
      const save = pending();
      const actions = { ...everything(), onSave: vi.fn(() => save.promise) };
      render(<Page first={picture} onClosed={onClosed} actions={actions} />);
      const idle = row('갤러리에 저장');

      fireEvent.click(idle);

      expect(actions.onSave).toHaveBeenCalledTimes(1);
      expect(actions.onSave).toHaveBeenCalledWith(picture);
      const status = within(sheet()).getByRole('status');
      expect(status.textContent).toBe('저장 중…');
      expect(status.tagName).toBe('DIV');
      expect(status.hasAttribute('tabindex')).toBe(false);
      const spinner = status.querySelector('svg');
      expect(spinner?.getAttribute('aria-hidden')).toBe('true');
      expect(spinner?.getAttribute('class')).toContain('animate-spin');
      expect(spinner?.getAttribute('class')).toContain('motion-reduce:animate-none');
      // It is no button any more, and a tap that was on its way finds nothing.
      expect(within(sheet()).queryByRole('button', { name: '갤러리에 저장' })).toBeNull();
      fireEvent.click(idle);
      expect(actions.onSave).toHaveBeenCalledTimes(1);
      // Its own phase only: the other rows are as they were.
      expect(row('공유')).toBeTruthy();
      expect(onClosed).not.toHaveBeenCalled();

      await act(async () => save.end(saved));
      await until(() => onClosed.mock.calls.length > 0);

      expect(onClosed).toHaveBeenCalledTimes(1);
      expect(screen.queryByRole('dialog')).toBeNull();
    });

    it('closes the sheet when the gallery has to be allowed first: the page says what to do', async () => {
      const onClosed = vi.fn();
      const save = pending();
      render(
        <Page
          first={picture}
          onClosed={onClosed}
          actions={{ onCopy: vi.fn(), onSave: () => save.promise }}
        />
      );
      fireEvent.click(row('갤러리에 저장'));

      await act(async () => save.end(failedWith('permission')));
      await until(() => onClosed.mock.calls.length > 0);

      expect(onClosed).toHaveBeenCalledTimes(1);
      expect(screen.queryByRole('dialog')).toBeNull();
    });

    it.each(['canceled', 'inProgress'] as const)(
      'puts the row back at rest when the saving was %s, and the sheet stays',
      async (type) => {
        const onClosed = vi.fn();
        const save = pending();
        render(
          <Page
            first={picture}
            onClosed={onClosed}
            actions={{ onCopy: vi.fn(), onSave: () => save.promise }}
          />
        );
        fireEvent.click(row('갤러리에 저장'));
        expect(within(sheet()).getByRole('status').textContent).toBe('저장 중…');

        await act(async () => save.end(failedWith(type)));

        expect(within(sheet()).getByRole('button', { name: '갤러리에 저장' })).toBeTruthy();
        expect(within(sheet()).queryByRole('status')).toBeNull();
        expect(within(sheet()).queryByRole('alert')).toBeNull();
        expect(onClosed).not.toHaveBeenCalled();
      }
    );

    it.each(['network', 'unexpected'] as const)(
      'says in the row that saving failed (%s), and a tap on it saves again',
      async (type) => {
        const onClosed = vi.fn();
        const first = pending();
        const onSave = vi
          .fn()
          .mockReturnValueOnce(first.promise)
          .mockReturnValueOnce(pending().promise);
        render(<Page first={picture} onClosed={onClosed} actions={{ onCopy: vi.fn(), onSave }} />);
        fireEvent.click(row('갤러리에 저장'));

        await act(async () => first.end({ ok: false, failure: { type, detail: 'timeout' } }));

        const failed = within(sheet()).getByRole('alert');
        expect(failed.getAttribute('aria-label')).toBe('저장 실패, 탭하여 재시도');
        expect(failed.textContent).toBe('저장에 실패했어요 · 탭하여 재시도');
        expect(failed.className).toContain('text-destructive');
        expect(failed.querySelector('svg')?.getAttribute('class')).toContain('lucide-circle-alert');
        expect(onClosed).not.toHaveBeenCalled();

        fireEvent.click(failed);

        expect(onSave).toHaveBeenCalledTimes(2);
        expect(within(sheet()).getByRole('status').textContent).toBe('저장 중…');
      }
    );

    it('takes a promise that broke off as a failure to try again, not a row that waits for ever', async () => {
      render(
        <Page
          first={picture}
          onClosed={() => undefined}
          actions={{
            onCopy: vi.fn(),
            onSave: async () => Promise.reject(new Error('plugin gone')),
          }}
        />
      );
      fireEvent.click(row('갤러리에 저장'));

      await settle();

      expect(within(sheet()).getByRole('alert').getAttribute('aria-label')).toBe(
        '저장 실패, 탭하여 재시도'
      );
    });
  });

  describe('공유', () => {
    it('is a status while it prepares, and the sheet closes once the media is offered', async () => {
      const onClosed = vi.fn();
      const share = pending();
      const actions = { ...everything(), onShare: vi.fn(() => share.promise) };
      render(<Page first={embed} onClosed={onClosed} actions={actions} />);

      fireEvent.click(row('공유'));

      expect(actions.onShare).toHaveBeenCalledWith(embed);
      const status = within(sheet()).getByRole('status');
      expect(status.textContent).toBe('준비 중…');
      expect(within(sheet()).queryByRole('button', { name: '공유' })).toBeNull();
      expect(onClosed).not.toHaveBeenCalled();

      await act(async () => share.end(saved));
      await until(() => onClosed.mock.calls.length > 0);

      expect(onClosed).toHaveBeenCalledTimes(1);
    });

    it.each(['canceled', 'inProgress'] as const)(
      'puts the row back at rest when the sharing was %s',
      async (type) => {
        const onClosed = vi.fn();
        const share = pending();
        render(
          <Page
            first={picture}
            onClosed={onClosed}
            actions={{ onCopy: vi.fn(), onShare: () => share.promise }}
          />
        );
        fireEvent.click(row('공유'));

        await act(async () => share.end(failedWith(type)));

        expect(within(sheet()).getByRole('button', { name: '공유' })).toBeTruthy();
        expect(onClosed).not.toHaveBeenCalled();
      }
    );

    it('closes the sheet when sharing needs something allowed first', async () => {
      const onClosed = vi.fn();
      const share = pending();
      render(
        <Page
          first={picture}
          onClosed={onClosed}
          actions={{ onCopy: vi.fn(), onShare: () => share.promise }}
        />
      );
      fireEvent.click(row('공유'));

      await act(async () => share.end(failedWith('permission')));
      await until(() => onClosed.mock.calls.length > 0);

      expect(onClosed).toHaveBeenCalledTimes(1);
    });

    it('says in the row that sharing failed, and a tap on it shares again', async () => {
      const onClosed = vi.fn();
      const first = pending();
      const onShare = vi
        .fn()
        .mockReturnValueOnce(first.promise)
        .mockReturnValueOnce(pending().promise);
      render(<Page first={clip} onClosed={onClosed} actions={{ onCopy: vi.fn(), onShare }} />);
      fireEvent.click(row('공유'));

      await act(async () => first.end(failedWith('network')));

      const failed = within(sheet()).getByRole('alert');
      expect(failed.getAttribute('aria-label')).toBe('공유 실패, 탭하여 재시도');
      expect(failed.textContent).toBe('공유에 실패했어요 · 탭하여 재시도');
      expect(failed.className).toContain('text-destructive');
      expect(onClosed).not.toHaveBeenCalled();

      fireEvent.click(failed);

      expect(onShare).toHaveBeenCalledTimes(2);
      expect(within(sheet()).getByRole('status').textContent).toBe('준비 중…');
    });
  });

  it.each([
    ['a save', '갤러리에 저장'],
    ['a share', '공유'],
  ] as const)(
    'nothing of %s outlives the sheet: a result that lands after the sheet closed changes nothing, and closes nothing again',
    async (_kind, name) => {
      const onClosed = vi.fn();
      const work = pending();
      const actions = { onCopy: vi.fn(), onSave: () => work.promise, onShare: () => work.promise };
      render(<Page first={picture} onClosed={onClosed} actions={actions} />);
      fireEvent.click(row(name));
      expect(within(sheet()).getByRole('status')).toBeTruthy();

      // Closed for a reason of its own while the row runs.
      await closeByEsc(onClosed);
      expect(screen.queryByRole('dialog')).toBeNull();
      await settle();

      await act(async () => {
        work.end(saved);
        await Promise.resolve();
      });
      await settle();

      expect(onClosed).toHaveBeenCalledTimes(1);
      expect(screen.queryByRole('dialog')).toBeNull();
      expect(screen.queryByRole('alert')).toBeNull();
      expect(screen.queryByRole('status')).toBeNull();
      expect(document.body.style.overflow).toBe('');
      expect(window.history.state).toEqual(HOME);
    }
  );

  it('a result that lands after the sheet closed with a failure leaves no row behind either', async () => {
    const onClosed = vi.fn();
    const work = pending();
    render(
      <Page
        first={picture}
        onClosed={onClosed}
        actions={{ onCopy: vi.fn(), onSave: () => work.promise }}
      />
    );
    fireEvent.click(row('갤러리에 저장'));

    await closeByEsc(onClosed);
    await act(async () => work.end(failedWith('network')));
    await settle();

    expect(onClosed).toHaveBeenCalledTimes(1);
    expect(screen.queryByRole('alert')).toBeNull();
  });

  it('a row is never left running for another target: its result closes nothing', async () => {
    const onClosed = vi.fn();
    const save = pending();
    render(<Retargetable onClosed={onClosed} onSave={() => save.promise} />);
    fireEvent.click(row('갤러리에 저장'));
    expect(within(sheet()).getByRole('status').textContent).toBe('저장 중…');

    // The page moves the sheet to a video while the picture is still being saved.
    act(() => retarget(clip));

    expect(within(sheet()).queryByRole('status')).toBeNull();
    expect(row('갤러리에 저장').querySelector('svg')?.getAttribute('class')).toContain(
      'lucide-download'
    );

    await act(async () => save.end(saved));
    await settle();

    expect(onClosed).not.toHaveBeenCalled();
    expect(screen.getByRole('dialog')).toBeTruthy();
  });
});
