// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { Comment } from '../../src/model/comment';
import type { FeedItem } from '../../src/model/feed_item';
import { NetworkFailure, ServerFailure } from '../../src/model/failures';
import type { LoadedPostDetail } from '../../src/model/post_detail';
import { FeedCard } from '../../src/widgets/feed_card';

const post = (extra: Partial<FeedItem> = {}): FeedItem => ({
  community: 'humoruniv',
  id: '7',
  title: '제목입니다',
  url: '/board/read.html?table=pds&number=7',
  author: '길동이',
  recommendCount: 3,
  commentCount: 1,
  viewCount: 20,
  ...extra,
});

const detail = (extra: Partial<LoadedPostDetail> = {}): LoadedPostDetail => ({
  status: 'loaded',
  id: 7,
  community: 'humoruniv',
  title: '제목입니다',
  author: '길동이',
  date: new Date(2026, 10, 1),
  contentBlocks: [],
  imageUrls: [],
  recommendCount: 3,
  notRecommendCount: 0,
  viewCount: 20,
  commentCount: 4,
  comments: [],
  ...extra,
});

const comment = (id: number, extra: Partial<Comment> = {}): Comment => ({
  id,
  author: '댓글러',
  content: '첫 댓글',
  date: new Date(2026, 10, 1),
  recommendCount: 0,
  isBest: false,
  mediaBlocks: [],
  replies: [],
  ...extra,
});

describe('FeedCard', () => {
  afterEach(() => vi.restoreAllMocks());

  it('shows who wrote it, the counts and the title', () => {
    render(<FeedCard post={post()} />);

    expect(screen.getByText('길동이')).toBeTruthy();
    expect(screen.getByRole('heading', { level: 2, name: '제목입니다' })).toBeTruthy();
    expect(screen.getByText('3')).toBeTruthy();
    expect(screen.getByText('20')).toBeTruthy();
  });

  it('counts the comments the body lists once it has arrived, replies included', () => {
    render(
      <FeedCard
        post={post({ commentCount: 99, recommendCount: 5 })}
        detail={detail({
          commentCount: 99,
          comments: [comment(1, { replies: [comment(11)] }), comment(2)],
        })}
      />
    );

    expect(screen.getByText('3')).toBeTruthy();
    expect(screen.getByText('댓글 3개 모두 보기')).toBeTruthy();
  });

  it('keeps what the listing counted until the body arrives', () => {
    render(<FeedCard post={post({ commentCount: 4 })} />);

    expect(screen.getByText('4')).toBeTruthy();
    expect(screen.queryByText(/모두 보기/)).toBeNull();
  });

  it('counts no comment once the body arrived without one, whatever the site counted', () => {
    render(<FeedCard post={post({ commentCount: 4 })} detail={detail({ commentCount: 4 })} />);

    expect(screen.getByText('0')).toBeTruthy();
    expect(screen.queryByText(/모두 보기/)).toBeNull();
  });

  it('marks a post with 500 recommends or more as BEST', () => {
    render(<FeedCard post={post({ recommendCount: 500 })} />);
    expect(screen.getByText('BEST')).toBeTruthy();

    render(<FeedCard post={post({ recommendCount: 499 })} />);
    expect(screen.getAllByText('BEST')).toHaveLength(1);
  });

  it('gives the copy button its name and calls the handler', () => {
    const onCopyLink = vi.fn();

    render(<FeedCard post={post()} onCopyLink={onCopyLink} />);
    fireEvent.click(screen.getByRole('button', { name: '링크 복사' }));

    expect(onCopyLink).toHaveBeenCalledTimes(1);
  });

  it('shows the text and the first comment of the body', () => {
    render(
      <FeedCard
        post={post()}
        detail={detail({
          contentBlocks: [{ type: 'text', text: '여기가 본문입니다.' }],
          comments: [
            {
              id: 1,
              author: '댓글러',
              content: '첫 댓글',
              date: new Date(2026, 10, 1),
              recommendCount: 0,
              isBest: true,
              mediaBlocks: [],
              replies: [],
            },
          ],
        })}
      />
    );

    expect(screen.getByText('여기가 본문입니다.')).toBeTruthy();
    expect(screen.getByText('댓글 1개 모두 보기')).toBeTruthy();
    expect(
      screen.getByText(
        (_, element) => element?.tagName === 'P' && element.textContent === '댓글러 첫 댓글'
      )
    ).toBeTruthy();
  });

  it('opens an address of the text in a new page', () => {
    render(
      <FeedCard
        post={post()}
        detail={detail({ contentBlocks: [{ type: 'text', text: '보기 https://example.com/a' }] })}
      />
    );

    const link = screen.getByRole('link', { name: 'https://example.com/a' });
    expect(link).toHaveProperty('target', '_blank');
  });

  it('offers 더보기 only while the text is cut off, and 접기 once it is open', () => {
    vi.spyOn(HTMLElement.prototype, 'scrollHeight', 'get').mockReturnValue(120);
    vi.spyOn(HTMLElement.prototype, 'clientHeight', 'get').mockReturnValue(60);

    render(
      <FeedCard
        post={post()}
        detail={detail({ contentBlocks: [{ type: 'text', text: '긴 글' }] })}
      />
    );
    const more = screen.getByRole('button', { name: '더보기' });
    expect(more).toHaveProperty('ariaExpanded', 'false');

    fireEvent.click(more);

    expect(screen.getByRole('button', { name: '접기' })).toHaveProperty('ariaExpanded', 'true');
  });

  it('offers no 더보기 when the text fits', () => {
    vi.spyOn(HTMLElement.prototype, 'scrollHeight', 'get').mockReturnValue(60);
    vi.spyOn(HTMLElement.prototype, 'clientHeight', 'get').mockReturnValue(60);

    render(
      <FeedCard
        post={post()}
        detail={detail({ contentBlocks: [{ type: 'text', text: '짧은 글' }] })}
      />
    );

    expect(screen.queryByRole('button', { name: '더보기' })).toBeNull();
  });

  it('waits for the media of a body that is still coming', () => {
    render(<FeedCard post={post()} detailLoading />);

    expect(screen.getByRole('progressbar', { name: '이미지 불러오는 중' })).toBeTruthy();
  });

  it('saves from a button named by whether the post is saved', () => {
    const onToggleBookmark = vi.fn();
    const { rerender } = render(<FeedCard post={post()} onToggleBookmark={onToggleBookmark} />);

    const save = screen.getByRole('button', { name: '저장' });
    expect(save.getAttribute('aria-pressed')).toBe('false');
    fireEvent.click(save);
    expect(onToggleBookmark).toHaveBeenCalledTimes(1);

    rerender(<FeedCard post={post()} bookmarked onToggleBookmark={onToggleBookmark} />);
    expect(screen.getByRole('button', { name: '저장 취소' }).getAttribute('aria-pressed')).toBe(
      'true'
    );
  });

  it('has no save button when nothing can save, and the copy button is no toggle', () => {
    render(<FeedCard post={post()} onCopyLink={() => undefined} />);

    expect(screen.queryByRole('button', { name: '저장' })).toBeNull();
    expect(
      screen.getByRole('button', { name: '링크 복사' }).getAttribute('aria-pressed')
    ).toBeNull();
  });

  it('keeps the card and says why the body is missing, with a way to try again', () => {
    const onRetry = vi.fn();
    render(<FeedCard post={post()} bodyError={new ServerFailure('x')} onRetry={onRetry} />);

    expect(screen.getByRole('heading', { level: 2, name: '제목입니다' })).toBeTruthy();
    expect(screen.getByRole('alert').textContent).toContain('불러오기 실패 — 서버 오류');
    fireEvent.click(screen.getByText('다시 시도'));
    expect(onRetry).toHaveBeenCalledTimes(1);
  });

  it('says that it cannot connect, and that what is shown was saved earlier', () => {
    render(
      <FeedCard post={post()} bodyError={new NetworkFailure('x')} onRetry={() => undefined} />
    );

    expect(screen.getByRole('alert').textContent).toContain(
      '연결할 수 없어 본문을 불러올 수 없어요'
    );
    expect(screen.getByText('저장한 때의 글만 보여요')).toBeTruthy();
  });

  it('says the post is gone, and offers no way to try again', () => {
    const gone = new ServerFailure('x', { statusCode: 404, headers: {}, bodySnippet: '' });
    const onRetry = vi.fn();
    render(<FeedCard post={post()} bodyError={gone} onRetry={onRetry} />);

    expect(screen.getByRole('alert').textContent).toContain('삭제되었거나 비공개된 게시물이에요');
    expect(screen.queryByText('다시 시도')).toBeNull();
  });

  describe('the saved picture of a post', () => {
    /** The image loads of the test: nothing loads here unless the test says it did. */
    const loads: FakeImage[] = [];

    class FakeImage {
      onload: (() => void) | null = null;
      onerror: (() => void) | null = null;
      referrerPolicy = '';
      readonly src: string;

      constructor(src: string) {
        this.src = src;
        loads.push(this);
      }
    }

    beforeEach(() => {
      loads.length = 0;
      vi.stubGlobal('Image', FakeImage);
    });
    afterEach(() => vi.unstubAllGlobals());

    it('shows what a saved post looked like in its listing when its body did not come', async () => {
      render(
        <FeedCard
          post={post({ thumbnailUrl: 'https://e.com/a.jpg' })}
          bodyError={new ServerFailure('x')}
        />
      );
      expect(loads[0]).toMatchObject({ src: 'https://e.com/a.jpg', referrerPolicy: 'no-referrer' });
      expect(screen.queryByRole('img')).toBeNull();

      await act(() => loads[0].onload?.());

      expect(screen.getByRole('img', { name: '저장할 때의 미리보기 그림' })).toBeTruthy();
    });

    it('asks for no saved picture next to a post whose body did come', () => {
      render(
        <FeedCard
          post={post({ thumbnailUrl: 'https://e.com/a.jpg' })}
          detail={detail({ contentBlocks: [{ type: 'text', text: '본문' }] })}
        />
      );

      expect(loads).toHaveLength(0);
    });
  });

  describe('the way to the comments', () => {
    afterEach(cleanup);

    it('opens them from the preview, a button named by what it shows', () => {
      const onOpenComments = vi.fn();
      render(
        <FeedCard
          post={post()}
          detail={detail({ comments: [comment(1), comment(2)] })}
          onOpenComments={onOpenComments}
        />
      );

      fireEvent.click(screen.getByRole('button', { name: /댓글 2개 모두 보기/ }));

      expect(onOpenComments).toHaveBeenCalledTimes(1);
    });

    it('leaves the preview as text where nothing can open the comments', () => {
      render(<FeedCard post={post()} detail={detail({ comments: [comment(1)] })} />);

      expect(screen.getByText('댓글 1개 모두 보기').closest('button')).toBeNull();
    });
  });
});
