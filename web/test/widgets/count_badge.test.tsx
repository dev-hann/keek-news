// @vitest-environment jsdom
import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { CommentBadge, RecommendBadge, ViewBadge } from '../../src/widgets/count_badge';

describe('the count badges of a post', () => {
  it('say what is counted: the icon alone does not', () => {
    render(
      <p>
        <RecommendBadge count={3} />
        <CommentBadge count={0} />
        <ViewBadge count={20} />
      </p>
    );

    expect(screen.getByLabelText('추천 3')).toBeTruthy();
    expect(screen.getByLabelText('댓글 0')).toBeTruthy();
    expect(screen.getByLabelText('조회 20')).toBeTruthy();
    expect(screen.getByText('0')).toBeTruthy();
  });
});
