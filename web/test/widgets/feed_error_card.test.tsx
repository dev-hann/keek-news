// @vitest-environment jsdom
import { fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import type { FeedItem } from '../../src/model/feed_item';
import { NetworkFailure, ParseFailure, ServerFailure } from '../../src/model/failures';
import { FeedErrorCard } from '../../src/widgets/feed_error_card';

const post: FeedItem = {
  community: 'humoruniv',
  id: '9',
  title: 't',
  url: 'u',
  recommendCount: 0,
  commentCount: 0,
  viewCount: 0,
};

describe('FeedErrorCard', () => {
  it.each([
    [new NetworkFailure('x'), '불러오기 실패 — 네트워크 오류'],
    [new ServerFailure('x'), '불러오기 실패 — 서버 오류'],
    [new ParseFailure('x'), '불러오기 실패 — 차단 또는 구조 변경 가능성'],
  ])('says why in the words of a reader: %s', (failure, message) => {
    render(<FeedErrorCard post={post} failure={failure} onCopyError={() => undefined} />);

    expect(screen.getByRole('alert')).toBeTruthy();
    expect(screen.getByText(message)).toBeTruthy();
    expect(screen.getByText('웃긴대학')).toBeTruthy();
  });

  it('tries again and copies the error report through the handlers of the page', () => {
    const onRetry = vi.fn();
    const onCopyError = vi.fn();
    const failure = new ServerFailure('503');
    render(
      <FeedErrorCard post={post} failure={failure} onRetry={onRetry} onCopyError={onCopyError} />
    );

    fireEvent.click(screen.getByRole('button', { name: '다시 시도' }));
    fireEvent.click(screen.getByRole('button', { name: '오류 정보 복사' }));

    expect(onRetry).toHaveBeenCalledTimes(1);
    expect(onCopyError).toHaveBeenCalledTimes(1);
  });

  it('has no 다시 시도 when the page gives no way to try again', () => {
    render(
      <FeedErrorCard post={post} failure={new ServerFailure('x')} onCopyError={() => undefined} />
    );

    expect(screen.queryByRole('button', { name: '다시 시도' })).toBeNull();
  });
});
