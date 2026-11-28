// @vitest-environment jsdom
import { fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import type { FeedItem } from '../../src/model/feed_item';
import { NetworkFailure, ServerFailure } from '../../src/model/failures';
import type { LoadedPostDetail, PostDetail } from '../../src/model/post_detail';
import { FeedDetailCard } from '../../src/widgets/feed_detail_card';

const post: FeedItem = {
  community: 'humoruniv',
  id: '7',
  title: '제목입니다',
  url: '/board/read.html?table=pds&number=7',
  author: '길동이',
  recommendCount: 3,
  commentCount: 1,
  viewCount: 20,
};

const body: LoadedPostDetail = {
  status: 'loaded',
  id: 7,
  community: 'humoruniv',
  title: '제목입니다',
  author: '길동이',
  date: new Date(2026, 10, 1),
  contentBlocks: [{ type: 'text', text: '여기가 본문입니다.' }],
  imageUrls: [],
  recommendCount: 3,
  notRecommendCount: 0,
  viewCount: 20,
  commentCount: 0,
  comments: [],
};

const failed: PostDetail = {
  status: 'error',
  id: 7,
  community: 'humoruniv',
  failure: new ServerFailure('x'),
};

const props = {
  post,
  detailLoading: false,
  onRetry: vi.fn(),
  onCopyLink: vi.fn(),
  onCopyError: vi.fn(),
};

describe('FeedDetailCard', () => {
  it('shows the body of a post that was read', () => {
    render(<FeedDetailCard {...props} detail={body} />);

    expect(screen.getByText('여기가 본문입니다.')).toBeTruthy();
  });

  it('takes the place of a post whose body failed', () => {
    render(<FeedDetailCard {...props} detail={failed} />);

    expect(screen.getByRole('alert').textContent).toContain('불러오기 실패 — 서버 오류');
    expect(screen.queryByRole('heading', { level: 2 })).toBeNull();
  });

  it('keeps the card of a saved post whose body failed, with the reason inside it', () => {
    const onRetry = vi.fn();
    render(<FeedDetailCard {...props} detail={failed} keepOnBodyError onRetry={onRetry} />);

    expect(screen.getByRole('heading', { level: 2, name: '제목입니다' })).toBeTruthy();
    expect(screen.getByText('길동이')).toBeTruthy();
    expect(screen.getByRole('alert').textContent).toContain('불러오기 실패 — 서버 오류');

    fireEvent.click(screen.getByText('다시 시도'));
    expect(onRetry).toHaveBeenCalledTimes(1);
  });

  it('keeps the card of a saved post that cannot be reached', () => {
    render(
      <FeedDetailCard
        {...props}
        detail={{
          status: 'error',
          id: 7,
          community: 'humoruniv',
          failure: new NetworkFailure('x'),
        }}
        keepOnBodyError
      />
    );

    expect(screen.getByRole('heading', { level: 2, name: '제목입니다' })).toBeTruthy();
    expect(screen.getByRole('alert').textContent).toContain(
      '연결할 수 없어 본문을 불러올 수 없어요'
    );
  });

  it('offers saving in every state of the body, and says whether the post is saved', () => {
    const onToggleBookmark = vi.fn();
    const { rerender } = render(
      <FeedDetailCard {...props} onToggleBookmark={onToggleBookmark} bookmarked />
    );
    const saved = () => screen.queryByRole('button', { name: '저장 취소' });

    expect(saved()?.getAttribute('aria-pressed')).toBe('true');
    fireEvent.click(saved()!);
    expect(onToggleBookmark).toHaveBeenCalledTimes(1);

    rerender(<FeedDetailCard {...props} detail={body} onToggleBookmark={onToggleBookmark} />);
    expect(screen.getByRole('button', { name: '저장' }).getAttribute('aria-pressed')).toBe('false');

    // An error card takes the place of the post in a feed: nothing of the post is left to save.
    rerender(<FeedDetailCard {...props} detail={failed} onToggleBookmark={onToggleBookmark} />);
    expect(screen.queryByRole('button', { name: '저장' })).toBeNull();

    rerender(
      <FeedDetailCard
        {...props}
        detail={failed}
        keepOnBodyError
        onToggleBookmark={onToggleBookmark}
      />
    );
    expect(screen.getByRole('button', { name: '저장' })).toBeTruthy();
  });

  it('offers no save button when nothing can save', () => {
    render(<FeedDetailCard {...props} detail={body} />);

    expect(screen.queryByRole('button', { name: '저장' })).toBeNull();
  });
});
