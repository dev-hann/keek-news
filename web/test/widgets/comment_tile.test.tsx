// @vitest-environment jsdom
import { act, fireEvent, render, screen, within } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { Comment } from '../../src/model/comment';
import type { ContentBlock, VideoBlock } from '../../src/model/content_block';
import type { MediaTarget } from '../../src/model/media_target';
import { CommentTile } from '../../src/widgets/comment_tile';

const comment = (id: number, extra: Partial<Comment> = {}): Comment => ({
  id,
  author: '길동이',
  content: '웃긴 글 잘 보고 갑니다',
  date: new Date(2026, 10, 28, 9),
  recommendCount: 3,
  isBest: false,
  mediaBlocks: [],
  replies: [],
  ...extra,
});

/** The comment of `text`, as the element that holds it. */
function line(text: string): HTMLElement {
  return screen.getByText(text).closest('p') as HTMLElement;
}

/** The comment that `author` wrote, as its item of the list. */
function item(author: string): HTMLElement {
  return screen.getByText(author).closest('li') as HTMLElement;
}

const FIRST = 'https://e.com/a.jpg';
const SECOND = 'https://e.com/b.jpg';
const THIRD = 'https://e.com/c.jpg';
const CLIP: VideoBlock = {
  type: 'video',
  url: 'https://e.com/v.mp4',
  thumbnailUrl: 'https://e.com/v.jpg',
};

const clip = (url: string, extra: Partial<VideoBlock> = {}): VideoBlock => ({
  type: 'video',
  url,
  ...extra,
});

/** The classes of an element one by one. */
const classes = (element: Element): string[] => element.className.split(/\s+/);

const finger = { pointerId: 7, isPrimary: true, button: 0, clientX: 100, clientY: 100 };

/** Lets the pointer go where it pressed, and the click that follows that. */
function release(target: Element): void {
  fireEvent.pointerUp(target, { pointerId: 7 });
  fireEvent(target, new PointerEvent('click', { bubbles: true, cancelable: true, pointerId: 7 }));
}

/** A finger moving over, or leaving, `target`; says whether the picture kept the browser from acting on it. */
function touch(kind: 'touchmove' | 'touchend', target: Element): boolean {
  const event = new Event(kind, { bubbles: true, cancelable: true });
  target.dispatchEvent(event);
  return event.defaultPrevented;
}

describe('CommentTile', () => {
  afterEach(() => vi.useRealTimers());

  it('says who wrote it, when, how many recommended it, and what it says', () => {
    vi.setSystemTime(new Date(2026, 10, 28, 12));
    const { container } = render(
      <ul>
        <CommentTile comment={comment(1)} />
      </ul>
    );

    const author = screen.getByText('길동이');
    expect(author.className).toContain('font-bold');
    expect(screen.getByText('3시간 전')).toBeTruthy();
    expect(screen.getByText('3')).toBeTruthy();
    // Said with the number, since the icon alone says nothing.
    expect(screen.getByText('3').parentElement?.textContent).toBe('추천 3');
    expect(line('웃긴 글 잘 보고 갑니다').className).toContain('text-base');
    // Read only: nothing in it acts.
    expect(container.querySelector('button, a, [role="button"], [tabindex]')).toBeNull();
  });

  it('shows a recommend count of 0 instead of hiding it', () => {
    render(
      <ul>
        <CommentTile comment={comment(1, { recommendCount: 0 })} />
      </ul>
    );

    expect(screen.getByText('0')).toBeTruthy();
    expect(screen.getByText('0').parentElement?.textContent).toBe('추천 0');
  });

  it('is marked BEST when it is a best comment', () => {
    render(
      <ul>
        <CommentTile comment={comment(1, { isBest: true })} />
      </ul>
    );

    expect(screen.getByText('BEST')).toBeTruthy();
  });

  it('has no mark when it is an ordinary comment', () => {
    render(
      <ul>
        <CommentTile comment={comment(1)} />
      </ul>
    );

    expect(screen.queryByText('BEST')).toBeNull();
  });

  it('makes an address of the text a link', () => {
    render(
      <ul>
        <CommentTile comment={comment(1, { content: '여기 보세요 https://example.com/a' })} />
      </ul>
    );

    expect(screen.getByRole('link', { name: 'https://example.com/a' })).toHaveProperty(
      'target',
      '_blank'
    );
  });

  it('says nothing for an empty text', () => {
    const { container } = render(
      <ul>
        <CommentTile comment={comment(1, { content: '' })} />
      </ul>
    );

    expect(container.querySelector('p')).toBeNull();
  });

  it('lists a reply under its comment: nested, indented, a step smaller, muted, behind a line', () => {
    render(
      <ul>
        <CommentTile
          comment={comment(1, {
            replies: [comment(11, { author: '철수', content: '답글입니다' })],
          })}
        />
      </ul>
    );

    const parent = item('길동이');
    const reply = item('철수');

    // A list in a list keeps the reply under the comment it answers.
    expect(reply.parentElement?.tagName).toBe('UL');
    expect(parent.contains(reply)).toBe(true);
    // 16px in for a reply.
    expect(reply.classList.contains('pl-4')).toBe(true);
    expect(parent.classList.contains('pl-4')).toBe(false);
    expect(reply.className).toContain('before:bg-border');
    // A step smaller and muted; the comment itself is not.
    expect(line('답글입니다').className).toContain('text-sm');
    expect(line('답글입니다').className).toContain('text-muted-foreground');
    expect(line('웃긴 글 잘 보고 갑니다').className).not.toContain('text-muted-foreground');
  });

  it('lists a reply to a reply one level further in', () => {
    render(
      <ul>
        <CommentTile
          comment={comment(1, {
            replies: [
              comment(11, {
                author: '철수',
                content: '답글',
                replies: [comment(111, { author: '영희', content: '답글의 답글' })],
              }),
            ],
          })}
        />
      </ul>
    );

    const reply = item('철수');
    const replyToReply = item('영희');

    expect(reply.contains(replyToReply)).toBe(true);
    expect(replyToReply.parentElement?.tagName).toBe('UL');
    expect(replyToReply.classList.contains('pl-4')).toBe(true);
    expect(screen.getAllByRole('listitem')).toHaveLength(3);
  });

  it('shows the image of a comment and the poster of its video as pictures that do nothing', () => {
    const { container } = render(
      <ul>
        <CommentTile
          comment={comment(1, {
            mediaBlocks: [
              { type: 'image', url: 'https://e.com/a.jpg' },
              { type: 'video', url: 'https://e.com/v.mp4', thumbnailUrl: 'https://e.com/v.jpg' },
              { type: 'video', url: 'https://e.com/w.mp4' },
              { type: 'text', text: 'not a picture' },
            ],
          })}
        />
      </ul>
    );

    const pictures = screen.getAllByRole('img');
    expect(pictures.map((picture) => picture.getAttribute('src'))).toEqual([
      'https://e.com/a.jpg',
      'https://e.com/v.jpg',
    ]);
    expect(pictures.map((picture) => picture.getAttribute('alt'))).toEqual([
      '길동이의 댓글 이미지',
      '길동이의 댓글 동영상',
    ]);
    for (const picture of pictures) {
      // jsdom knows no `loading` property: the attribute is what the browser reads.
      expect(picture.getAttribute('loading')).toBe('lazy');
      expect(picture.closest('button, a, [role="button"]')).toBeNull();
    }
    // No player, no play icon, no control of any kind.
    expect(container.querySelector('video')).toBeNull();
    expect(container.querySelector('[class*="play" i]')).toBeNull();
    expect(container.querySelector('button, a')).toBeNull();
  });
  describe('the media of a comment', () => {
    /** Two pictures with a video between them, then a third picture: the place of a picture counts pictures only. */
    const media = (): ContentBlock[] => [
      { type: 'image', url: FIRST },
      CLIP,
      { type: 'image', url: SECOND },
      { type: 'image', url: THIRD },
    ];

    it('a picture is a button, 44px at least, that opens the viewer on it: counted among the images of the comment, not among all its media', () => {
      const onOpenImage = vi.fn<(images: string[], index: number) => void>();
      render(
        <ul>
          <CommentTile comment={comment(1, { mediaBlocks: media() })} onOpenImage={onOpenImage} />
        </ul>
      );

      const first = screen.getByRole('button', { name: '길동이의 댓글 이미지 1' });
      const third = screen.getByRole('button', { name: '길동이의 댓글 이미지 3' });
      expect(classes(first)).toContain('h-18');
      expect(first.querySelector('img')?.getAttribute('src')).toBe(FIRST);
      // The button is what is named: the picture inside it does not say it a second time.
      expect(first.querySelector('img')?.getAttribute('alt')).toBe('');
      // With no player to open, the video between them stays a plain picture, named as it was.
      expect(
        screen.getByRole('img', { name: '길동이의 댓글 동영상' }).closest('button')
      ).toBeNull();

      fireEvent.click(first);
      fireEvent.click(third);

      expect(onOpenImage.mock.calls).toEqual([
        [[FIRST, SECOND, THIRD], 0],
        [[FIRST, SECOND, THIRD], 2],
      ]);
    });

    it('the poster of a video is a button, named for its author, that opens the player: a play icon says so', () => {
      const onOpenVideo = vi.fn<(video: VideoBlock) => void>();
      render(
        <ul>
          <CommentTile comment={comment(1, { mediaBlocks: [CLIP] })} onOpenVideo={onOpenVideo} />
        </ul>
      );

      const video = screen.getByRole('button', { name: '길동이의 댓글 동영상' });
      expect(classes(video)).toContain('h-18');
      expect(video.querySelector('img')?.getAttribute('src')).toBe('https://e.com/v.jpg');
      const icon = video.querySelector('svg');
      expect(icon?.getAttribute('aria-hidden')).toBe('true');
      // Only the button is named: the poster in it is not.
      expect(screen.queryByRole('img', { name: '길동이의 댓글 동영상' })).toBeNull();

      fireEvent.click(video);

      expect(onOpenVideo).toHaveBeenCalledTimes(1);
      expect(onOpenVideo).toHaveBeenCalledWith(CLIP);
    });

    it('a video that has no poster is still that button, a muted box the size of a thumbnail with the icon', () => {
      const onOpenVideo = vi.fn<(video: VideoBlock) => void>();
      const bare = clip('https://e.com/w.mp4');
      render(
        <ul>
          <CommentTile comment={comment(1, { mediaBlocks: [bare] })} onOpenVideo={onOpenVideo} />
        </ul>
      );

      const video = screen.getByRole('button', { name: '길동이의 댓글 동영상' });
      expect(video.querySelector('img')).toBeNull();
      expect(classes(video)).toEqual(expect.arrayContaining(['h-18', 'w-18', 'bg-muted']));
      expect(video.querySelector('svg[aria-hidden="true"]')).not.toBeNull();

      fireEvent.click(video);

      expect(onOpenVideo).toHaveBeenCalledWith(bare);
    });

    it('a video that has no poster is nothing where no player can open it: no thumbnail, not even an empty row', () => {
      const { container } = render(
        <ul>
          <CommentTile comment={comment(1, { mediaBlocks: [clip('https://e.com/w.mp4')] })} />
        </ul>
      );

      expect(screen.queryByRole('img')).toBeNull();
      expect(screen.queryByRole('button')).toBeNull();
      expect(container.querySelector('.select-none')).toBeNull();
    });

    it("the media of a reply, and of a reply's reply, open the same way, each counted among its own comment's", () => {
      const onOpenImage = vi.fn<(images: string[], index: number) => void>();
      const onOpenVideo = vi.fn<(video: VideoBlock) => void>();
      const replyClip = clip('https://e.com/r.mp4', { thumbnailUrl: 'https://e.com/r.jpg' });
      render(
        <ul>
          <CommentTile
            comment={comment(1, {
              replies: [
                comment(11, {
                  author: '철수',
                  content: '답글',
                  mediaBlocks: [
                    { type: 'image', url: FIRST },
                    replyClip,
                    { type: 'image', url: SECOND },
                  ],
                  replies: [
                    comment(111, {
                      author: '영희',
                      content: '답글의 답글',
                      mediaBlocks: [{ type: 'image', url: THIRD }],
                    }),
                  ],
                }),
              ],
            })}
            onOpenImage={onOpenImage}
            onOpenVideo={onOpenVideo}
          />
        </ul>
      );

      // The comment itself has nothing to open: every button is a reply's, three of the reply and one of its reply.
      expect(within(item('길동이')).getAllByRole('button')).toHaveLength(4);
      fireEvent.click(within(item('철수')).getByRole('button', { name: '철수의 댓글 이미지 2' }));
      fireEvent.click(within(item('철수')).getByRole('button', { name: '철수의 댓글 동영상' }));
      fireEvent.click(within(item('영희')).getByRole('button', { name: '영희의 댓글 이미지 1' }));

      expect(onOpenImage.mock.calls).toEqual([
        [[FIRST, SECOND], 1],
        [[THIRD], 0],
      ]);
      expect(onOpenVideo.mock.calls).toEqual([[replyClip]]);
    });
  });

  describe('the long press', () => {
    /** A picture and the poster of a video. */
    const media = (): ContentBlock[] => [{ type: 'image', url: FIRST }, CLIP];

    beforeEach(() => {
      vi.useFakeTimers();
    });

    it('a finger held on a picture for half a second asks for the media menu, for that picture: once, and not before', () => {
      const onMore = vi.fn<(target: MediaTarget) => void>();
      render(
        <ul>
          <CommentTile
            comment={comment(1, { mediaBlocks: [{ type: 'image', url: FIRST }] })}
            onOpenImage={vi.fn()}
            onMore={onMore}
          />
        </ul>
      );
      const picture = screen.getByRole('button', { name: '길동이의 댓글 이미지 1' });

      // The finger lands on the picture inside the button.
      fireEvent.pointerDown(picture.querySelector('img') as Element, finger);
      act(() => vi.advanceTimersByTime(499));
      expect(onMore).not.toHaveBeenCalled();

      act(() => vi.advanceTimersByTime(1));
      expect(onMore).toHaveBeenCalledTimes(1);
      expect(onMore).toHaveBeenCalledWith({ url: FIRST, kind: 'image' });

      // However long the finger stays.
      act(() => vi.advanceTimersByTime(5000));
      expect(onMore).toHaveBeenCalledTimes(1);
    });

    it('held on a video, asks for the video; on an embed from outside the community, for the embed', () => {
      const onMore = vi.fn<(target: MediaTarget) => void>();
      const embed = clip('https://youtu.be/abc', { thumbnailUrl: 'https://e.com/e.jpg' });
      render(
        <ul>
          <CommentTile
            comment={comment(1, { mediaBlocks: [CLIP, embed] })}
            onOpenVideo={vi.fn()}
            onMore={onMore}
          />
        </ul>
      );
      const [clipButton, embedButton] = screen.getAllByRole('button', {
        name: '길동이의 댓글 동영상',
      });

      fireEvent.pointerDown(clipButton, finger);
      act(() => vi.advanceTimersByTime(500));
      fireEvent.pointerUp(clipButton, { pointerId: 7 });
      fireEvent.pointerDown(embedButton, finger);
      act(() => vi.advanceTimersByTime(500));

      expect(onMore.mock.calls).toEqual([
        [{ url: 'https://e.com/v.mp4', kind: 'video' }],
        [{ url: 'https://youtu.be/abc', kind: 'external' }],
      ]);
    });

    it("held on a reply's picture, asks for that picture: the replies get the menu too, from the comment alone", () => {
      const onMore = vi.fn<(target: MediaTarget) => void>();
      render(
        <ul>
          <CommentTile
            comment={comment(1, {
              replies: [
                comment(11, {
                  author: '철수',
                  content: '답글',
                  mediaBlocks: [{ type: 'image', url: FIRST }],
                  replies: [
                    comment(111, {
                      author: '영희',
                      content: '답글의 답글',
                      mediaBlocks: [{ type: 'image', url: SECOND }],
                    }),
                  ],
                }),
              ],
            })}
            onMore={onMore}
          />
        </ul>
      );

      fireEvent.pointerDown(screen.getByRole('img', { name: '철수의 댓글 이미지' }), finger);
      act(() => vi.advanceTimersByTime(500));
      fireEvent.pointerUp(screen.getByRole('img', { name: '철수의 댓글 이미지' }), {
        pointerId: 7,
      });
      fireEvent.pointerDown(screen.getByRole('img', { name: '영희의 댓글 이미지' }), finger);
      act(() => vi.advanceTimersByTime(500));

      expect(onMore.mock.calls).toEqual([
        [{ url: FIRST, kind: 'image' }],
        [{ url: SECOND, kind: 'image' }],
      ]);
    });

    it('held on a video that has no poster, asks for the video', () => {
      const onMore = vi.fn<(target: MediaTarget) => void>();
      render(
        <ul>
          <CommentTile
            comment={comment(1, { mediaBlocks: [clip('https://e.com/w.mp4')] })}
            onOpenVideo={vi.fn()}
            onMore={onMore}
          />
        </ul>
      );

      fireEvent.pointerDown(screen.getByRole('button', { name: '길동이의 댓글 동영상' }), finger);
      act(() => vi.advanceTimersByTime(500));

      expect(onMore).toHaveBeenCalledWith({ url: 'https://e.com/w.mp4', kind: 'video' });
    });

    it('a plain picture is pressed long too, where only the menu is given: it stays no button', () => {
      const onMore = vi.fn<(target: MediaTarget) => void>();
      render(
        <ul>
          <CommentTile comment={comment(1, { mediaBlocks: media() })} onMore={onMore} />
        </ul>
      );
      const picture = screen.getByRole('img', { name: '길동이의 댓글 이미지' });
      const poster = screen.getByRole('img', { name: '길동이의 댓글 동영상' });
      expect(picture.closest('button, [role="button"]')).toBeNull();
      expect(poster.closest('button, [role="button"]')).toBeNull();

      fireEvent.pointerDown(picture, finger);
      act(() => vi.advanceTimersByTime(500));
      fireEvent.pointerUp(picture, { pointerId: 7 });
      fireEvent.pointerDown(poster, finger);
      act(() => vi.advanceTimersByTime(500));

      expect(onMore.mock.calls).toEqual([
        [{ url: FIRST, kind: 'image' }],
        [{ url: 'https://e.com/v.mp4', kind: 'video' }],
      ]);
    });

    it('is no long press when the finger is let go first, moves more than about 10px, or the browser takes the gesture', () => {
      const onMore = vi.fn();
      render(
        <ul>
          <CommentTile
            comment={comment(1, { mediaBlocks: [{ type: 'image', url: FIRST }] })}
            onOpenImage={vi.fn()}
            onMore={onMore}
          />
        </ul>
      );
      const picture = screen.getByRole('button', { name: '길동이의 댓글 이미지 1' });

      // Let go first: that is a tap.
      fireEvent.pointerDown(picture, finger);
      act(() => vi.advanceTimersByTime(300));
      fireEvent.pointerUp(picture, { pointerId: 7 });
      act(() => vi.advanceTimersByTime(1000));

      // Moved: that is a drag, as a scroll of the list begins.
      fireEvent.pointerDown(picture, finger);
      act(() => vi.advanceTimersByTime(200));
      fireEvent.pointerMove(picture, { pointerId: 7, clientX: 115, clientY: 100 });
      act(() => vi.advanceTimersByTime(1000));
      fireEvent.pointerUp(picture, { pointerId: 7 });

      // Taken by the browser.
      fireEvent.pointerDown(picture, finger);
      act(() => vi.advanceTimersByTime(200));
      fireEvent.pointerCancel(picture, { pointerId: 7 });
      act(() => vi.advanceTimersByTime(1000));

      expect(onMore).not.toHaveBeenCalled();
    });

    it('still counts when the finger trembles a little', () => {
      const onMore = vi.fn();
      render(
        <ul>
          <CommentTile
            comment={comment(1, { mediaBlocks: [{ type: 'image', url: FIRST }] })}
            onMore={onMore}
          />
        </ul>
      );
      // The thumb is the picture itself here: nothing opens on a tap.
      const picture = screen.getByRole('img', { name: '길동이의 댓글 이미지' });

      fireEvent.pointerDown(picture, finger);
      act(() => vi.advanceTimersByTime(200));
      fireEvent.pointerMove(picture, { pointerId: 7, clientX: 106, clientY: 105 });
      act(() => vi.advanceTimersByTime(300));

      expect(onMore).toHaveBeenCalledTimes(1);
    });

    it('is for the first finger and the main button only', () => {
      const onMore = vi.fn();
      render(
        <ul>
          <CommentTile
            comment={comment(1, { mediaBlocks: [{ type: 'image', url: FIRST }] })}
            onOpenImage={vi.fn()}
            onMore={onMore}
          />
        </ul>
      );
      const picture = screen.getByRole('button', { name: '길동이의 댓글 이미지 1' });

      fireEvent.pointerDown(picture, { ...finger, isPrimary: false });
      fireEvent.pointerDown(picture, { ...finger, button: 2 });
      act(() => vi.advanceTimersByTime(1000));

      expect(onMore).not.toHaveBeenCalled();
    });

    it('letting go of a long press is not also a tap, and the next tap is one', () => {
      const onMore = vi.fn();
      const onOpenImage = vi.fn<(images: string[], index: number) => void>();
      render(
        <ul>
          <CommentTile
            comment={comment(1, { mediaBlocks: [{ type: 'image', url: FIRST }] })}
            onOpenImage={onOpenImage}
            onMore={onMore}
          />
        </ul>
      );
      const picture = screen.getByRole('button', { name: '길동이의 댓글 이미지 1' });

      fireEvent.pointerDown(picture, finger);
      act(() => vi.advanceTimersByTime(500));
      expect(onMore).toHaveBeenCalledTimes(1);
      release(picture);
      expect(onOpenImage).not.toHaveBeenCalled();

      fireEvent.pointerDown(picture, finger);
      release(picture);

      expect(onOpenImage).toHaveBeenCalledTimes(1);
      expect(onOpenImage).toHaveBeenCalledWith([FIRST], 0);
      expect(onMore).toHaveBeenCalledTimes(1);
    });

    it('a click of the keyboard is never taken for how a long press ended', () => {
      const onMore = vi.fn();
      const onOpenImage = vi.fn<(images: string[], index: number) => void>();
      render(
        <ul>
          <CommentTile
            comment={comment(1, { mediaBlocks: [{ type: 'image', url: FIRST }] })}
            onOpenImage={onOpenImage}
            onMore={onMore}
          />
        </ul>
      );
      const picture = screen.getByRole('button', { name: '길동이의 댓글 이미지 1' });

      // A mouse that pressed long and was let go elsewhere: its click never came here.
      fireEvent.pointerDown(picture, { ...finger, pointerId: 1 });
      act(() => vi.advanceTimersByTime(500));
      fireEvent.pointerUp(picture, { pointerId: 1 });
      expect(onMore).toHaveBeenCalledTimes(1);

      // Enter on the picture: a click from no pointer at all, as Chromium sends it.
      fireEvent(
        picture,
        new PointerEvent('click', { bubbles: true, cancelable: true, pointerId: -1 })
      );
      fireEvent(picture, new MouseEvent('click', { bubbles: true, cancelable: true }));

      expect(onOpenImage).toHaveBeenCalledTimes(2);
    });

    it('keeps a finger that pressed long from moving the list, and its letting go from being a click', () => {
      const onMore = vi.fn();
      render(
        <ul>
          <CommentTile
            comment={comment(1, { mediaBlocks: [{ type: 'image', url: FIRST }] })}
            onOpenImage={vi.fn()}
            onMore={onMore}
          />
        </ul>
      );
      const picture = screen.getByRole('button', { name: '길동이의 댓글 이미지 1' });

      // Free to become a scroll of the list.
      expect(touch('touchmove', picture)).toBe(false);
      fireEvent.pointerDown(picture, finger);
      expect(touch('touchmove', picture)).toBe(false);

      act(() => vi.advanceTimersByTime(500));
      // Held long: the sheet is open, a move now scrolls nothing.
      expect(touch('touchmove', picture)).toBe(true);
      // The browser would click where the finger lifts: that is the scrim of the sheet.
      expect(touch('touchend', picture)).toBe(true);

      // A new press is free again.
      fireEvent.pointerUp(picture, { pointerId: 7 });
      fireEvent.pointerDown(picture, finger);
      expect(touch('touchmove', picture)).toBe(false);
      expect(touch('touchend', picture)).toBe(false);
    });

    it('keeps the WebView from selecting the media and from offering its own menu on a long press', () => {
      render(
        <ul>
          <CommentTile
            comment={comment(1, { mediaBlocks: media() })}
            onOpenImage={vi.fn()}
            onOpenVideo={vi.fn()}
          />
        </ul>
      );
      const picture = screen.getByRole('button', { name: '길동이의 댓글 이미지 1' });
      const video = screen.getByRole('button', { name: '길동이의 댓글 동영상' });
      const row = picture.parentElement as HTMLElement;

      expect(row.className).toContain('select-none');
      expect(row.className).toContain('[-webkit-touch-callout:none]');
      // fireEvent says false when the page kept the browser from its default.
      expect(fireEvent.contextMenu(picture)).toBe(false);
      expect(fireEvent.contextMenu(picture.querySelector('img') as Element)).toBe(false);
      expect(fireEvent.contextMenu(video)).toBe(false);
    });

    it('watches nothing where the page has no menu to open', () => {
      render(
        <ul>
          <CommentTile
            comment={comment(1, { mediaBlocks: [{ type: 'image', url: FIRST }] })}
            onOpenImage={vi.fn()}
          />
        </ul>
      );
      const picture = screen.getByRole('button', { name: '길동이의 댓글 이미지 1' });

      fireEvent.pointerDown(picture, finger);
      act(() => vi.advanceTimersByTime(1000));

      expect(touch('touchmove', picture)).toBe(false);
    });

    it('forgets a press it was still watching when the comment goes', () => {
      const onMore = vi.fn();
      const { unmount } = render(
        <ul>
          <CommentTile
            comment={comment(1, { mediaBlocks: [{ type: 'image', url: FIRST }] })}
            onMore={onMore}
          />
        </ul>
      );

      fireEvent.pointerDown(screen.getByRole('img', { name: '길동이의 댓글 이미지' }), finger);
      unmount();
      act(() => vi.advanceTimersByTime(1000));

      expect(onMore).not.toHaveBeenCalled();
    });
  });
});
