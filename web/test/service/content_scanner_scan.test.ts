// @vitest-environment jsdom
import { describe, expect, it } from 'vitest';
import type {
  ContentBlock,
  HtmlBlock,
  ImageBlock,
  TextBlock,
  VideoBlock,
} from '../../src/model/content_block';
import {
  scanContent,
  scanContentCompact,
  scanContentFull,
} from '../../src/service/content_scanner';
import { parseHtml } from '../../src/service/html_service';

const imageBlocks = (blocks: ContentBlock[]) =>
  blocks.filter((b): b is ImageBlock => b.type === 'image');
const textBlocks = (blocks: ContentBlock[]) =>
  blocks.filter((b): b is TextBlock => b.type === 'text');
const videoBlocks = (blocks: ContentBlock[]) =>
  blocks.filter((b): b is VideoBlock => b.type === 'video');
const htmlBlocks = (blocks: ContentBlock[]) =>
  blocks.filter((b): b is HtmlBlock => b.type === 'html');

/** The list's only element; fails the test when there is not exactly one. */
function single<T>(items: T[]): T {
  expect(items).toHaveLength(1);
  return items[0];
}

describe('ContentScanner scan methods', () => {
  describe('scan', () => {
    it('should extract text as TextBlock', () => {
      const doc = parseHtml('<div class="body_editor">Hello world</div>');
      const container = doc.querySelector('.body_editor')!;

      const result = scanContent(container);

      expect(result.blocks).toHaveLength(1);
      expect(result.blocks[0]).toMatchObject({ type: 'text' });
      expect((result.blocks[0] as TextBlock).text).toBe('Hello world');
    });

    it('should extract image from img tag', () => {
      const doc = parseHtml(`
          <div class="body_editor">
            <div class="simple_attach_img_div">
              <img src="http://example.com/img.jpg" img_file_url="http://example.com/img.jpg" class="img_compress" />
            </div>
          </div>
        `);
      const container = doc.querySelector('.body_editor')!;

      const result = scanContent(container);

      expect(result.blocks.some((b) => b.type === 'image')).toBe(true);
      expect(result.imageUrls).toContain('http://example.com/img.jpg');
    });

    it('should extract image with thumbnail', () => {
      const doc = parseHtml(`
          <div class="body_editor">
            <img src="http://example.com/thumb.jpg" img_file_url="http://example.com/full.jpg" class="img_compress" />
          </div>
        `);
      const container = doc.querySelector('.body_editor')!;

      const result = scanContent(container);

      const img = imageBlocks(result.blocks)[0];
      expect(img?.url).toBe('http://example.com/full.jpg');
      expect(img?.thumbnailUrl).toBe('http://example.com/thumb.jpg');
    });

    it('should preserve order of text and images', () => {
      const doc = parseHtml(`
          <div class="body_editor">
            Text before
            <img src="http://example.com/img.jpg" img_file_url="http://example.com/img.jpg" class="img_compress" />
            Text after
          </div>
        `);
      const container = doc.querySelector('.body_editor')!;

      const result = scanContent(container);

      const types = [...result.blocks.map((b) => b.type)];
      expect(types).toContain('text');
      expect(types).toContain('image');

      const textBeforeIdx = result.blocks.findIndex(
        (b) => b.type === 'text' && b.text.includes('Text before')
      );
      const imgIdx = result.blocks.findIndex((b) => b.type === 'image');
      const textAfterIdx = result.blocks.findIndex(
        (b) => b.type === 'text' && b.text.includes('Text after')
      );

      expect(textBeforeIdx).toBeLessThan(imgIdx);
      expect(imgIdx).toBeLessThan(textAfterIdx);
    });

    it('should skip noise elements', () => {
      const doc = parseHtml(`
          <div class="body_editor">
            <div class="comment_thumb_notice">some notice</div>
            <div class="comment_crop_href">crop link</div>
            <div class="comment_crop_href_mp4">mp4 crop</div>
            <iframe src="http://example.com"></iframe>
            <p>Actual content</p>
          </div>
        `);
      const container = doc.querySelector('.body_editor')!;

      const result = scanContent(container);

      const texts = textBlocks(result.blocks).map((b) => b.text);
      expect(texts).not.toContain('some notice');
      expect(texts).not.toContain('crop link');
      expect(texts).not.toContain('mp4 crop');
      expect(texts).toContain('Actual content');
    });

    it('should skip images with /images/ path', () => {
      const doc = parseHtml(`
          <div class="body_editor">
            <img src="/images/spacer.gif" />
          </div>
        `);
      const container = doc.querySelector('.body_editor')!;

      const result = scanContent(container);

      expect(imageBlocks(result.blocks)).toHaveLength(0);
    });

    it('should detect video element as VideoBlock', () => {
      const doc = parseHtml(`
          <div class="body_editor">
            <div>
              <video width="480" height="360" poster="http://example.com/thumb.jpg" controls>
                <source src="http://example.com/video.mp4" type="video/mp4">
              </video>
            </div>
          </div>
        `);
      const container = doc.querySelector('.body_editor')!;

      const result = scanContent(container);

      expect(result.blocks.some((b) => b.type === 'video')).toBe(true);
      const video = videoBlocks(result.blocks)[0];
      expect(video?.url).toBe('http://example.com/video.mp4');
      expect(video?.thumbnailUrl).toBe('http://example.com/thumb.jpg');
      expect(video?.width).toBe(480);
      expect(video?.height).toBe(360);
    });

    it('should extract YouTube link as VideoBlock', () => {
      const doc = parseHtml(`
          <div class="body_editor">
            <span class="autolink"><a href="https://www.youtube.com/watch?v=dQw4w9WgXcQ">youtube link</a></span>
          </div>
        `);
      const container = doc.querySelector('.body_editor')!;

      const result = scanContent(container);

      expect(result.blocks.some((b) => b.type === 'video')).toBe(true);
      const video = videoBlocks(result.blocks)[0];
      expect(video?.url).toContain('youtube.com');
      expect(video?.thumbnailUrl).toContain('img.youtube.com');
    });

    it('should extract link as HtmlBlock', () => {
      const doc = parseHtml(`
          <div class="body_editor">
            <span class="autolink"><a href="https://example.com/page">visit page</a></span>
          </div>
        `);
      const container = doc.querySelector('.body_editor')!;

      const result = scanContent(container);

      expect(result.blocks.some((b) => b.type === 'html')).toBe(true);
      const html = htmlBlocks(result.blocks)[0];
      expect(html?.html).toContain('href="https://example.com/page"');
      expect(html?.html).toContain('visit page');
    });

    it('should deduplicate URLs', () => {
      const doc = parseHtml(`
          <div class="body_editor">
            <div class="simple_attach_img_div">
              <img src="http://example.com/img.jpg" img_file_url="http://example.com/img.jpg" class="img_compress" />
            </div>
            <div class="comment_img_div">
              <img src="http://example.com/img.jpg" img_file_url="http://example.com/img.jpg" class="img_compress" />
            </div>
          </div>
        `);
      const container = doc.querySelector('.body_editor')!;

      const result = scanContent(container);

      expect(imageBlocks(result.blocks)).toHaveLength(1);
    });

    it('should normalize // URLs to https://', () => {
      const doc = parseHtml(`
          <div class="body_editor">
            <img src="//timg.humoruniv.com/thumb.jpg" img_file_url="//timg.humoruniv.com/full.jpg" class="img_compress" />
          </div>
        `);
      const container = doc.querySelector('.body_editor')!;

      const result = scanContent(container);

      const img = imageBlocks(result.blocks)[0];
      expect(img?.url).toMatch(/^https:\/\//);
      expect(img?.thumbnailUrl).toMatch(/^https:\/\//);
    });

    it('should handle empty container', () => {
      const doc = parseHtml('<div class="body_editor"></div>');
      const container = doc.querySelector('.body_editor')!;

      const result = scanContent(container);

      expect(result.blocks).toHaveLength(0);
      expect(result.imageUrls).toHaveLength(0);
    });

    // Regression: humoruniv pds post 1419653 wraps GIF attachments as
    // <div class='comment_img_div'><a href='javascript:comment_thumb_expand'>
    //   <img class='comment_thumb_img' .../>
    //   <div class='comment_thumb_notice'>GIF</div>
    // </a></div>
    // The notice badge text ("GIF") must NOT leak as a TextBlock, because
    // the wrapper <a> is incorrectly treated as a simple-text element.
    it('should not emit GIF/MP4 notice badge text from attachment wrapper', () => {
      const doc = parseHtml(`
            <div class="body_editor">
              <div class="simple_attach_img_div">
                <div class="comment_img_div">
                  <a href="javascript:comment_thumb_expand('id', 'https://down.humoruniv.com/data/editor/a.gif', '//timg.humoruniv.com/thumb.php?url=https://down.humoruniv.com/data/editor/a.gif?SIZE=320x240', '320', '320', '', 'GIF', '');">
                    <img src="//timg.humoruniv.com/thumb.php?url=https://down.humoruniv.com/data/editor/a.gif?SIZE=320x240" class="comment_thumb_img" OnClick=""/>
                    <div class="comment_thumb_notice">GIF</div>
                  </a>
                  <div style="position:absolute;top:12px;left:12px;"><img src="/images/play_trans.png?tmp=3" width="40" height="40"/></div>
                </div>
              </div>
              <div class="simple_attach_img_div">
                <div class="comment_img_div pointer" OnClick="javascript:comment_mp4_expand('mp4_1_', 'https://down.humoruniv.com/data/editor/v.mp4', '//timg.humoruniv.com/thumb.php?url_enc=abc', '320', '320', '', 'MP4', '', '', '');">
                  <img src="//timg.humoruniv.com/thumb.php?url_enc=abc" class="comment_thumb_img"/>
                  <div class="comment_thumb_notice">MP4</div>
                  <div style="position:absolute;top:12px;left:12px;"><img src="/images/play_trans.png?tmp=3" width="40" height="40"/></div>
                </div>
              </div>
            </div>
          `);
      const container = doc.querySelector('.body_editor')!;

      const result = scanContent(container);

      const leakedNotices = textBlocks(result.blocks)
        .map((b) => b.text)
        .filter((t) => t === 'GIF' || t === 'MP4');
      expect(leakedNotices, 'GIF/MP4 attachment badges must not appear as body text').toHaveLength(
        0
      );
    });
  });

  describe('scanCompact', () => {
    it('should extract images from comment body', () => {
      const doc = parseHtml(`
          <div class="comment_body">
            <span class="comment_text">댓글 내용</span>
            <div class="comment_img_div">
              <img src="http://example.com/comment_img.jpg" img_file_url="http://example.com/comment_img.jpg" class="img_compress" />
            </div>
          </div>
        `);
      const container = doc.querySelector('.comment_body')!;

      const result = scanContentCompact(container);

      expect(result).toHaveLength(1);
      expect(result[0]).toMatchObject({ type: 'image' });
    });

    it('should extract video from onclick attribute', () => {
      const doc = parseHtml(`
          <div class="comment_body">
            <span class="comment_text">댓글</span>
            <div OnClick="comment_mp4_expand('123','http://example.com/video.mp4','http://example.com/thumb.jpg')">
              <img src="http://example.com/thumb.jpg" />
            </div>
          </div>
        `);
      const container = doc.querySelector('.comment_body')!;

      const result = scanContentCompact(container);

      expect(result.some((b) => b.type === 'video')).toBe(true);
      const video = videoBlocks(result)[0];
      expect(video?.url).toBe('http://example.com/video.mp4');
    });

    it(
      'should emit single VideoBlock for comment_mp4_expand container, ' +
        'dropping url_enc thumbnail (server returns 403) and no ImageBlock',
      () => {
        const doc = parseHtml(`
            <div class="comment_body">
              <div class='comment_file'>
                <div class='comment_img_div pointer' style='width:320px;'
                    OnClick="javascript:comment_mp4_expand('mp4_714827364_3530_', 'http://down.humoruniv.com/data/comment/video.mp4', 'http://timg.humoruniv.com/thumb.php?url_enc=abc', '320', '320', '', 'MP4', '0.4MB', '', '');">
                  <img src='http://timg.humoruniv.com/thumb.php?url_enc=abc' width='320' class='comment_thumb_img' style='min-height:80px;'/>
                  <div class='comment_thumb_notice'>MP4,&nbsp; 0.4MB</div>
                  <div style='position:absolute;top:12px;left:12px;'><img src='/images/play_trans.png?tmp=3' width='40' height='40'></div>
                </div>
              </div>
              <span class="comment_text">똥이나 처먹어!</span>
            </div>
          `);
        const container = doc.querySelector('.comment_body')!;

        const result = scanContentCompact(container);

        expect(result).toHaveLength(1);
        expect(imageBlocks(result)).toHaveLength(0);
        const video = single(videoBlocks(result));
        expect(video.url).toBe('http://down.humoruniv.com/data/comment/video.mp4');
        expect(
          video.thumbnailUrl,
          'url_enc thumbnails return 403 for any client; ' +
            'must be null so the UI can fall back to local frame extraction'
        ).toBeUndefined();
      }
    );

    it('comment_mp4_expand keeps plaintext thumb.php thumbnail', () => {
      const doc = parseHtml(`
            <div class="comment_body">
              <div class='comment_file'>
                <div class='comment_img_div pointer' style='width:320px;'
                    OnClick="javascript:comment_mp4_expand('mp4_1_', 'http://down.humoruniv.com/data/comment/video.mp4', 'http://timg.humoruniv.com/thumb.php?url=http://down.humoruniv.com/data/comment/v.jpg', '320', '320', '', 'MP4', '', '', '');">
                  <img src='http://timg.humoruniv.com/thumb.php?url=http://down.humoruniv.com/data/comment/v.jpg' width='320' class='comment_thumb_img'/>
                </div>
              </div>
            </div>
          `);
      const container = doc.querySelector('.comment_body')!;

      const result = scanContentCompact(container);
      const video = single(videoBlocks(result));
      expect(video.thumbnailUrl, 'plaintext thumb.php URLs are loadable (server renders PNG)').toBe(
        'http://timg.humoruniv.com/thumb.php?url=http://down.humoruniv.com/data/comment/v.jpg'
      );
    });

    it('should return empty list for text-only comment', () => {
      const doc = parseHtml(`
          <div class="comment_body">
            <span class="comment_text">그냥 텍스트 댓글</span>
          </div>
        `);
      const container = doc.querySelector('.comment_body')!;

      const result = scanContentCompact(container);

      expect(result).toHaveLength(0);
    });
  });

  describe('scanFull', () => {
    it('should scan content container and find inline images', () => {
      const doc = parseHtml(`
          <html><body>
          <div class="body_editor">
            <img src="http://example.com/img.jpg" img_file_url="http://example.com/img.jpg" class="img_compress" />
          </div>
          </body></html>
        `);
      const container = doc.querySelector('.body_editor')!;

      const result = scanContentFull(doc, container);

      expect(result.blocks.some((b) => b.type === 'image')).toBe(true);
    });

    it('should find download links outside content container', () => {
      const doc = parseHtml(`
          <html><body>
          <div class="body_editor">
            <p>Some text</p>
          </div>
          <div class="download_area">
            <a href="http://down.humoruniv.com/download.php?url=http://example.com/extra.jpg">
              <img src="http://example.com/extra_thumb.jpg" />
            </a>
          </div>
          </body></html>
        `);
      const container = doc.querySelector('.body_editor')!;

      const result = scanContentFull(doc, container);

      const imgs = imageBlocks(result.blocks);
      expect(imgs).toHaveLength(1);
      expect(imgs[0]?.url).toBe('http://example.com/extra.jpg');
    });

    it('should find download video outside content container', () => {
      const doc = parseHtml(`
          <html><body>
          <div class="body_editor">
            <p>Some text</p>
          </div>
          <div class="download_area">
            <a href="http://down.humoruniv.com/download.php?url=http://example.com/clip.mp4">
              <img src="http://example.com/clip_thumb.jpg" />
            </a>
          </div>
          </body></html>
        `);
      const container = doc.querySelector('.body_editor')!;

      const result = scanContentFull(doc, container);

      expect(result.blocks.some((b) => b.type === 'video')).toBe(true);
      const video = videoBlocks(result.blocks)[0];
      expect(video?.url).toBe('http://example.com/clip.mp4');
    });

    it('should not duplicate image found both inside and outside container', () => {
      const doc = parseHtml(`
          <html><body>
          <div class="body_editor">
            <div class="simple_attach_img_div">
              <img src="http://timg.humoruniv.com/editor/img001.jpg"
                   img_file_url="http://timg.humoruniv.com/editor/img001.jpg"
                   class="img_compress" />
            </div>
          </div>
          <div class="download_area">
            <a href="http://down.humoruniv.com/download.php?url=http://down.humoruniv.com/editor/img001.jpg">
              <img src="http://down.humoruniv.com/editor/img001.jpg" />
            </a>
          </div>
          </body></html>
        `);
      const container = doc.querySelector('.body_editor')!;

      const result = scanContentFull(doc, container);

      const imgs = imageBlocks(result.blocks);
      expect(imgs).toHaveLength(1);
    });

    it('should not duplicate when scheme differs (http vs https)', () => {
      const doc = parseHtml(`
          <html><body>
          <div class="body_editor">
            <img src="http://timg.humoruniv.com/editor/photo.jpg"
                 img_file_url="http://timg.humoruniv.com/editor/photo.jpg"
                 class="img_compress" />
          </div>
          <div class="download_area">
            <a href="https://down.humoruniv.com/download.php?url=https://down.humoruniv.com/editor/photo.jpg">
              <img src="https://down.humoruniv.com/editor/photo.jpg" />
            </a>
          </div>
          </body></html>
        `);
      const container = doc.querySelector('.body_editor')!;

      const result = scanContentFull(doc, container);

      const imgs = imageBlocks(result.blocks);
      expect(imgs).toHaveLength(1);
    });

    it('should not duplicate when domain differs but path is same', () => {
      const doc = parseHtml(`
          <html><body>
          <div class="body_editor">
            <img src="http://timg.humoruniv.com/hwiparambbs/data/editor/2505/test.jpg"
                 img_file_url="http://timg.humoruniv.com/hwiparambbs/data/editor/2505/test.jpg"
                 class="img_compress" />
          </div>
          <div class="download_area">
            <a href="download.php?url=http://down.humoruniv.com/hwiparambbs/data/editor/2505/test.jpg">
              <img src="http://down.humoruniv.com/hwiparambbs/data/editor/2505/test.jpg" />
            </a>
          </div>
          </body></html>
        `);
      const container = doc.querySelector('.body_editor')!;

      const result = scanContentFull(doc, container);

      const imgs = imageBlocks(result.blocks);
      expect(imgs).toHaveLength(1);
    });

    it('should allow different images from different paths', () => {
      const doc = parseHtml(`
          <html><body>
          <div class="body_editor">
            <img src="http://timg.humoruniv.com/editor/img001.jpg"
                 img_file_url="http://timg.humoruniv.com/editor/img001.jpg"
                 class="img_compress" />
          </div>
          <div class="download_area">
            <a href="download.php?url=http://down.humoruniv.com/editor/img002.jpg">
              <img src="http://down.humoruniv.com/editor/img002.jpg" />
            </a>
          </div>
          </body></html>
        `);
      const container = doc.querySelector('.body_editor')!;

      const result = scanContentFull(doc, container);

      const imgs = imageBlocks(result.blocks);
      expect(imgs).toHaveLength(2);
    });

    it('should include both imageUrls for gallery', () => {
      const doc = parseHtml(`
          <html><body>
          <div class="body_editor">
            <img src="http://example.com/a.jpg"
                 img_file_url="http://example.com/a.jpg"
                 class="img_compress" />
          </div>
          <div class="download_area">
            <a href="download.php?url=http://example.com/b.jpg">
              <img src="http://example.com/b_thumb.jpg" />
            </a>
          </div>
          </body></html>
        `);
      const container = doc.querySelector('.body_editor')!;

      const result = scanContentFull(doc, container);

      expect(result.imageUrls).toHaveLength(2);
    });

    it('should skip download links inside content container', () => {
      const doc = parseHtml(`
          <html><body>
          <div class="body_editor">
            <a href="download.php?url=http://example.com/img.jpg">
              <img src="http://example.com/img.jpg" img_file_url="http://example.com/img.jpg" class="img_compress" />
            </a>
          </div>
          </body></html>
        `);
      const container = doc.querySelector('.body_editor')!;

      const result = scanContentFull(doc, container);

      const imgs = imageBlocks(result.blocks);
      expect(imgs).toHaveLength(1);
    });
  });

  describe('daum-wm-content layout (no body_editor)', () => {
    it('should extract both image and text from wrap_copy container', () => {
      const doc = parseHtml(`
          <div class="daum-wm-content">
            <wrap_copy id="wrap_copy">
              <table width="100%" border="0" cellspacing="0" cellpadding="0">
                <tr><td align="center">
                  <div id="comment_file_file_2856297_141796028">
                    <div class="comment_img_div">
                      <img src="//timg.humoruniv.com/thumb.php?url=http://down.humoruniv.com/hwiparambbs/data/pds/test.jpg?SIZE=800x1066"
                           img_file_url="//down.humoruniv.com/hwiparambbs/data/pds/test.jpg"
                           class="img_compress" />
                    </div>
                  </div>
                </td></tr>
              </table>
              <p class="content_body_padding">
                웃긴자료 게시글 본문 텍스트입니다.
              </p>
            </wrap_copy>
          </div>
        `);
      const container = doc.querySelector('.daum-wm-content')!;

      const result = scanContent(container);

      const images = imageBlocks(result.blocks);
      const texts = textBlocks(result.blocks);
      expect(images).toHaveLength(1);
      expect(texts.length).toBeGreaterThan(0);
      expect(texts.some((t) => t.text.includes('본문 텍스트'))).toBe(true);
    });

    it('should preserve image-before-text order in daum-wm-content', () => {
      const doc = parseHtml(`
          <div class="daum-wm-content">
            <wrap_copy id="wrap_copy">
              <table width="100%" border="0" cellspacing="0" cellpadding="0">
                <tr><td align="center">
                  <div class="comment_img_div">
                    <img src="http://example.com/img.jpg"
                         img_file_url="http://example.com/img.jpg"
                         class="img_compress" />
                  </div>
                </td></tr>
              </table>
              <p class="content_body_padding">이미지 다음 텍스트</p>
            </wrap_copy>
          </div>
        `);
      const container = doc.querySelector('.daum-wm-content')!;

      const result = scanContent(container);

      const imgIdx = result.blocks.findIndex((b) => b.type === 'image');
      const textIdx = result.blocks.findIndex(
        (b) => b.type === 'text' && b.text.includes('이미지 다음')
      );
      expect(imgIdx).toBeLessThan(textIdx);
    });
  });
});
