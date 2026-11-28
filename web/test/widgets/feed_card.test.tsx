// @vitest-environment jsdom
import { fireEvent, render, screen } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { FeedItem } from '../../src/model/feed_item';
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

describe('FeedCard', () => {
  afterEach(() => vi.restoreAllMocks());

  it('shows who wrote it, the counts and the title', () => {
    render(<FeedCard post={post()} />);

    expect(screen.getByText('길동이')).toBeTruthy();
    expect(screen.getByRole('heading', { level: 2, name: '제목입니다' })).toBeTruthy();
    expect(screen.getByText('3')).toBeTruthy();
    expect(screen.getByText('20')).toBeTruthy();
  });

  it('takes the comment count from the body once the body has arrived', () => {
    render(<FeedCard post={post({ commentCount: 0 })} detail={detail({ commentCount: 4 })} />);

    expect(screen.getByText('4')).toBeTruthy();
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
    expect(screen.getByText('댓글 4개 모두 보기')).toBeTruthy();
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
});
