import { describe, expect, it } from 'vitest';
import type { ContentBlock } from '../../src/model/content_block';
import type { LoadedPostDetail } from '../../src/model/post_detail';
import { feedBodyText, htmlBlockText } from '../../src/utils/body_text';

const detail = (contentBlocks: ContentBlock[]): LoadedPostDetail => ({
  status: 'loaded',
  id: 1,
  community: 'humoruniv',
  title: 't',
  author: 'a',
  date: new Date(2026, 0, 1),
  contentBlocks,
  imageUrls: [],
  recommendCount: 0,
  notRecommendCount: 0,
  viewCount: 0,
  commentCount: 0,
  comments: [],
});

describe('htmlBlockText', () => {
  it('keeps the text of a link and its label', () => {
    expect(htmlBlockText('<a href="https://e.com/?a=1&amp;b=2">보기</a>')).toBe('보기');
  });

  it('turns line breaks into new lines and tags into spaces', () => {
    expect(htmlBlockText('첫줄<br>둘째 줄<b>굵게</b>  끝')).toBe('첫줄\n둘째 줄 굵게 끝');
  });

  it('decodes the entities a page uses for text', () => {
    expect(htmlBlockText('&lt;약관&gt; &quot;인용&quot;')).toBe('<약관> "인용"');
  });
});

describe('feedBodyText', () => {
  it('joins the text of text and rich blocks, one block per line', () => {
    expect(
      feedBodyText(
        detail([
          { type: 'text', text: '  본문  ' },
          { type: 'image', url: 'https://e.com/a.jpg' },
          { type: 'html', html: '<b>강조</b>' },
        ])
      )
    ).toBe('본문\n강조');
  });

  it('is null when the post has no words', () => {
    expect(feedBodyText(detail([{ type: 'text', text: '   ' }]))).toBeNull();
    expect(feedBodyText(detail([]))).toBeNull();
  });
});
