// @vitest-environment jsdom
import { render, screen } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { Comment } from '../../src/model/comment';
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
});
