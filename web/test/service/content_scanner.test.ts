// @vitest-environment jsdom
import { describe, expect, it } from 'vitest';
import type {
  ContentBlock,
  HtmlBlock,
  ImageBlock,
  VideoBlock,
} from '../../src/model/content_block';
import {
  scanContent,
  scanContentCompact,
  scanContentFull,
} from '../../src/service/content_scanner';
import { parseHtml } from '../../src/service/html_service';

function firstImage(blocks: ContentBlock[]): ImageBlock | undefined {
  return blocks.find((b): b is ImageBlock => b.type === 'image');
}

const imageBlocks = (blocks: ContentBlock[]) =>
  blocks.filter((b): b is ImageBlock => b.type === 'image');
const videoBlocks = (blocks: ContentBlock[]) =>
  blocks.filter((b): b is VideoBlock => b.type === 'video');
const htmlBlocks = (blocks: ContentBlock[]) =>
  blocks.filter((b): b is HtmlBlock => b.type === 'html');

describe('ContentScanner noise filtering', () => {
  it('skips 1px spacer images regardless of source path', () => {
    const doc = parseHtml(
      '<div><img src="https://cdn.example.com/skin/t.gif" width="8" ' +
        'height="1px"><img src="https://cdn.example.com/real.jpg"></div>'
    );
    const result = scanContent(doc.body);

    const images = imageBlocks(result.blocks);
    expect(images).toHaveLength(1);
    expect(images[0]?.url).toContain('real.jpg');
  });

  it('skips spacer-named images without dimensions', () => {
    const doc = parseHtml(
      '<div> ' +
        '<img src="https://cdn.example.com/spacer.gif" /> ' +
        '<img src="https://cdn.example.com/photo.webp" /> ' +
        '</div>'
    );
    const result = scanContent(doc.body);

    const images = imageBlocks(result.blocks);
    expect(images).toHaveLength(1);
    expect(images[0]?.url).toContain('photo.webp');
  });

  it('prefers data-src over placeholder src for lazy images', () => {
    const doc = parseHtml(
      '<div> ' + '<img src="blank.gif" data-src="https://cdn.example.com/a.jpg"> ' + '</div>'
    );
    const result = scanContent(doc.body);

    const image = firstImage(result.blocks);
    expect(image).toBeDefined();
    expect(image?.url).toBe('https://cdn.example.com/a.jpg');
  });

  it('keeps plain src when no lazy attributes exist', () => {
    const doc = parseHtml('<div><img src="https://cdn.example.com/b.png"></div>');
    const result = scanContent(doc.body);

    const image = firstImage(result.blocks);
    expect(image).toBeDefined();
    expect(image?.url).toBe('https://cdn.example.com/b.png');
  });

  it('link-dense chrome is not emitted as HtmlBlock', () => {
    const html = `
        <div><b><a href="/1">navigation menu item one</a>
        <a href="/2">navigation menu item two</a>
        <a href="/3">navigation menu item three</a></b></div>
      `;
    const doc = parseHtml(html);
    const result = scanContent(doc.body);

    expect(htmlBlocks(result.blocks)).toHaveLength(0);
  });

  it('genuine rich mixed content still becomes HtmlBlock', () => {
    const html = `
        <div><b>본문 강조 텍스트가 충분히 길게 있는 문장입니다. '
        <a href="https://x.com">참고 링크</a> 그리고 마무리 문장.</b></div>
      `;
    const doc = parseHtml(html);
    const result = scanContent(doc.body);

    expect(htmlBlocks(result.blocks).length).toBeGreaterThan(0);
  });
});

describe('ContentScanner autolink anchors (href == text)', () => {
  // humoruniv comment images are autolink `<a href=url>url</a>` markup —
  // no `<img>` at all. The anchor must still yield an image block.
  it('scanContentCompact turns image autolinks into image blocks', () => {
    const url =
      'https://down.humoruniv.com/hwiparambbs/data/comment/' +
      '2017/02/worldcup_15253_1487330699.96832.png';
    const html = `
<div class="comment_body"><div class="comment_more">
<span class="autolink"><a href="${url}" title="${url}" >${url}</a>
</span></div></div>
`;
    const doc = parseHtml(html);
    const blocks = scanContentCompact(doc.body);

    const images = imageBlocks(blocks);
    expect(images).toHaveLength(1);
    expect(images[0]?.url).toBe(url);
  });

  it('scanContent emits image block for self-text image link', () => {
    const url = 'https://example.com/photo.jpg';
    const doc = parseHtml(`<div><a href="${url}">${url}</a></div>`);
    const result = scanContent(doc.body);

    expect(firstImage(result.blocks)?.url).toBe(url);
  });

  it('non-media self-text link stays a plain link', () => {
    const url = 'https://example.com/page';
    const doc = parseHtml(`<div><a href="${url}">${url}</a></div>`);
    const result = scanContent(doc.body);

    expect(imageBlocks(result.blocks)).toHaveLength(0);
    expect(htmlBlocks(result.blocks).length).toBeGreaterThan(0);
  });
});

describe('ContentScanner session-token thumbs (url_enc)', () => {
  // humoruniv `thumb.php?url_enc=…` URLs embed a per-session token that
  // expires after the page view; they must never become ImageBlocks
  // (dead carousel slot) nor VideoBlock posters (dead video frame).
  it('scanContent drops url_enc images and video posters', () => {
    const html = `
        <div>
          <div class="comment_img_div" onclick="comment_mp4_expand('x',
            'https://down.humoruniv.com/data/editor/a.mp4',
            '//timg.humoruniv.com/thumb.php?url_enc=TOKEN123',
            '348', '480', '', 'MP4', '', '', '');">
            <img src='//timg.humoruniv.com/thumb.php?url_enc=TOKEN123'
              class='comment_thumb_img'/>
          </div>
          <img src="https://down.humoruniv.com/data/editor/b.webp"/>
        </div>
      `;
    const doc = parseHtml(html);
    const result = scanContent(doc.body);

    const images = imageBlocks(result.blocks);
    expect(images).toHaveLength(1);
    expect(images[0]?.url).toContain('b.webp');
    expect(result.imageUrls).toHaveLength(1);
    expect(result.imageUrls[0]).toContain('b.webp');

    const videos = videoBlocks(result.blocks);
    expect(videos).toHaveLength(1);
    expect(videos[0]?.url).toContain('a.mp4');
    expect(videos[0]?.thumbnailUrl).toBeUndefined();
  });

  it('scanContentCompact drops url_enc images and video posters', () => {
    const html = `
        <div>
          <img src='//timg.humoruniv.com/thumb.php?url_enc=TOKEN123'/>
          <img src="https://down.humoruniv.com/data/editor/b.webp"/>
        </div>
      `;
    const doc = parseHtml(html);
    const blocks = scanContentCompact(doc.body);

    const images = imageBlocks(blocks);
    expect(images).toHaveLength(1);
    expect(images[0]?.url).toContain('b.webp');
  });
});

describe('ContentScanner doc-wide fallback excludes comment scopes', () => {
  // With session cookies humoruniv re-ships comment GIFs as
  // comment_mp4_expand divs inside `li[id^="comment_li_"]`. The doc-wide
  // fallback loops exist for post-body media OUTSIDE the content element
  // (attach lists), so anything inside a comment item must be skipped —
  // otherwise a comment's 1s gif→mp4 becomes a bogus second carousel
  // page on the post card.
  it('comment_mp4_expand inside comment li is skipped', () => {
    const html = `
        <html><body>
        <div class="body_editor"><p>본문</p></div>
        <ul>
          <li id="comment_li_516726485">
            <span class="comment_body">
              <div class="comment_img_div"
                onclick="comment_mp4_expand('cf_1',
                  '//down-mp4.humoruniv.com/f4/abc123.mp4',
                  '//timg.humoruniv.com/thumb.php?url=x.gif', '320', '800',
                  '', '', '63KB', '//x.gif', '1.2MB');">
              </div>
            </span>
          </li>
        </ul>
        </body></html>
      `;
    const doc = parseHtml(html);
    const contentEl = doc.querySelector('.body_editor')!;

    const result = scanContentFull(doc, contentEl);

    expect(videoBlocks(result.blocks)).toHaveLength(0);
  });

  it('download.php link inside best comment is skipped', () => {
    const html = `
        <html><body>
        <div class="body_editor"><p>본문</p></div>
        <div id="comment_best_wrap">
          <div class="best_li">
            <a href="download.php?url=https://down.humoruniv.com/data/c.png">
              <img src="https://timg.humoruniv.com/thumb.php?url=c.png"/>
            </a>
          </div>
        </div>
        </body></html>
      `;
    const doc = parseHtml(html);
    const contentEl = doc.querySelector('.body_editor')!;

    const result = scanContentFull(doc, contentEl);

    expect(imageBlocks(result.blocks)).toHaveLength(0);
    expect(result.imageUrls).toHaveLength(0);
  });

  it('attach-list media outside comments still collected', () => {
    const html = `
        <html><body>
        <div class="body_editor"><p>본문</p></div>
        <div id="list_download">
          <div class="comment_img_div"
            onclick="comment_mp4_expand('mp4_0_1',
              '//down.humoruniv.com/hwiparambbs/data/pds/body.mp4',
              '//timg.humoruniv.com/thumb.php?url=body.mp4', '348', '348',
              '', 'MP4', '', '', '');">
          </div>
        </div>
        </body></html>
      `;
    const doc = parseHtml(html);
    const contentEl = doc.querySelector('.body_editor')!;

    const result = scanContentFull(doc, contentEl);

    const videos = videoBlocks(result.blocks);
    expect(videos).toHaveLength(1);
    expect(videos[0]?.url).toContain('body.mp4');
  });
});
