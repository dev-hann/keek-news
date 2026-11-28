// @vitest-environment jsdom
import { describe, expect, it, vi } from 'vitest';
import type { Comment } from '../../../../src/model/comment';
import type {
  ContentBlock,
  ImageBlock,
  TextBlock,
  VideoBlock,
} from '../../../../src/model/content_block';
import { HumorunivImpl } from '../../../../src/repository/community/humoruniv/humoruniv_impl';
import { readFixture } from '../../../helpers/fixtures';

/** A client that answers every path containing a key with that fixture, as the Dart test's fakes did. */
function fixtureClient(fixtures: Record<string, string>) {
  return {
    get: vi.fn(async (path: string) => {
      const entry = Object.entries(fixtures).find(([key]) => path.includes(key));
      if (entry === undefined) throw new Error(`No fixture for: ${path}`);
      return entry[1];
    }),
  };
}

const read = (name: string): string => readFixture(name);

/** Every committed humoruniv detail fixture. Server markup drifts between
 * captures, so parser invariants are asserted across all of them. */
const detailFixtures = [
  'pds_1415455.html',
  'pds_1419653.html',
  'pds_1419769.html',
  'pds_1422694.html',
  'pds_1426857.html',
  'pds_1427341.html',
  'pds_1428508.html',
  'pds_1428549.html',
  'pds_1429732.html',
];

const humorunivListHtml = `
<html><body>
<div class="post_item"><a class="post_link" data-number="1422846"
 href="read.html?table=pds&amp;number=1422846">
<span class="link_hover">title</span></a></div>
<div id="pgnum">
<a class="def" href="list.html?table=pds&amp;pg=0">1</a>
<a class="def" href="list.html?table=pds&amp;pg=1">2</a>
<a class="def" href="list.html?table=pds&amp;pg=2">3</a>
</div>
</body></html>
`;

/** The client of the pagination tests: one list page, and a record of every path asked for. */
const recordingClient = () => fixtureClient({ 'list.html': humorunivListHtml });

const imageBlocks = (blocks: readonly ContentBlock[]) =>
  blocks.filter((b): b is ImageBlock => b.type === 'image');
const textBlocks = (blocks: readonly ContentBlock[]) =>
  blocks.filter((b): b is TextBlock => b.type === 'text');
const videoBlocks = (blocks: readonly ContentBlock[]) =>
  blocks.filter((b): b is VideoBlock => b.type === 'video');

/** The first comment passing `predicate`; fails the test when there is none, as Dart's `firstWhere` throws. */
function firstWhere(
  comments: readonly Comment[],
  what: string,
  predicate: (c: Comment) => boolean
): Comment {
  const hit = comments.find(predicate);
  expect(hit, `no ${what} matched`).toBeDefined();
  return hit!;
}

describe('HumorunivImpl.fetchDetail post title', () => {
  it('reads the title from the subject header', async () => {
    const repo = new HumorunivImpl(fixtureClient({ 'read.html': read('pds_1415455.html') }));

    const detail = await repo.fetchDetail('1415455');

    expect(detail.title).toBe('26일 어제, 태풍때문에 난리난 오사카');
  });

  it('falls back to <title> when the page has no subject header', async () => {
    const repo = new HumorunivImpl(fixtureClient({ 'read.html': read('pds_1429732.html') }));

    const detail = await repo.fetchDetail('1429732');

    expect(detail.title).toBe('던전의 시체 운반꾼 아가씨 만화.manhwa');
  });
});

describe('HumorunivImpl.fetchDetail comment dates', () => {
  it('regular comments do not fall back to epoch (1970)', async () => {
    const repo = new HumorunivImpl(fixtureClient({ 'read.html': read('pds_1415455.html') }));

    const detail = await repo.fetchDetail('1415455');

    expect(detail.comments.length).toBeGreaterThan(0);
    for (const c of detail.comments) {
      expect(
        c.date.getFullYear(),
        `comment date must not be epoch (1970): ${c.author} ${c.date.toISOString()}`
      ).toBeGreaterThanOrEqual(2020);
    }
  });

  it('parses regular comment date (단수돌침대 -> 2026-06-27)', async () => {
    const repo = new HumorunivImpl(fixtureClient({ 'read.html': read('pds_1415455.html') }));

    const detail = await repo.fetchDetail('1415455');

    const comment = firstWhere(detail.comments, 'comment', (c) => c.author === '단수돌침대');
    expect(comment.date).toEqual(new Date(2026, 5, 27, 18, 56, 44));
  });

  it('parses clean best comment date with time', async () => {
    const repo = new HumorunivImpl(fixtureClient({ 'read.html': read('pds_1415455.html') }));

    const detail = await repo.fetchDetail('1415455');

    const best = firstWhere(detail.comments, 'comment', (c) => c.author === '클로저스');
    expect(best.isBest).toBe(true);
    expect(best.date).toEqual(new Date(2026, 5, 27, 18, 57, 7));
  });

  it('long-nick best comment keeps author and year-anchored date', async () => {
    // humoruniv renders long nicks as a bare `.nick` with no inner
    // `.hu_nick_txt` and drops the year from the best-comment date
    // ("09-20 20:08:45").
    const repo = new HumorunivImpl(fixtureClient({ 'read.html': read('pds_1428549.html') }));

    const detail = await repo.fetchDetail('1428549');

    const best = firstWhere(detail.comments, 'best comment', (c) => c.isBest);
    expect(best.author).toBe('그래너라면가능하다');
    expect(best.date).toEqual(new Date(2026, 8, 20, 20, 8, 45));
  });

  it('year-less comment date anchors to the post year', async () => {
    // A comment can never predate its post, so a `MM-DD HH:MM:SS` date that
    // would is rolled into the next year.
    const repo = new HumorunivImpl(
      fixtureClient({
        'read.html': `
<html><body>
<p id="read_profile_desc"><span class="etc">작성 2026-12-30 10:00:00</span></p>
<div id="comment_best_wrap">
  <li class="best_li">
    <span class="nick">같은해에단긴닉네임</span>
    <span class="etc">12-31 09:00:00</span>
    <span class="comment_body">같은 해</span>
  </li>
  <li class="best_li">
    <span class="nick">다음해에단긴닉네임</span>
    <span class="etc">01-02 11:30:00</span>
    <span class="comment_body">다음 해</span>
  </li>
</div>
</body></html>
`,
      })
    );

    const detail = await repo.fetchDetail('1');

    expect(detail.comments.map((c) => c.date)).toEqual([
      new Date(2026, 11, 31, 9),
      new Date(2027, 0, 2, 11, 30),
    ]);
  });

  it('every comment on every detail fixture has an author and a date', async () => {
    for (const fixture of detailFixtures) {
      const repo = new HumorunivImpl(fixtureClient({ 'read.html': read(fixture) }));

      const detail = await repo.fetchDetail('0');

      const comments = detail.comments.flatMap((c) => [c, ...c.replies]);
      for (const c of comments) {
        expect(c.author, `${fixture} comment ${c.id}: no author`).not.toBe('');
        expect(
          c.date.getFullYear(),
          `${fixture} comment ${c.id} by "${c.author}": ${c.date.toISOString()}`
        ).toBeGreaterThan(2000);
      }
    }
  });
});

describe('HumorunivImpl.fetchDetail comment_more redesign (2026-08)', () => {
  // 2026-08 humoruniv dropped `.comment_text` and now wraps comment
  // bodies in `.comment_more` with a hidden-by-CSS sibling
  // `.comment_more_btn` rendered as `...전체보기`. The expander markup
  // ships in the HTML for EVERY comment, so the parser must read body
  // text from `.comment_more` and never leak the button text.
  it('comment content never leaks 전체보기 expander text', async () => {
    const repo = new HumorunivImpl(fixtureClient({ 'read.html': read('pds_1419769.html') }));

    const detail = await repo.fetchDetail('1419769');

    expect(detail.comments.length).toBeGreaterThan(0);
    for (const c of detail.comments) {
      expect(c.content, `comment by "${c.author}" leaked the expander: ${c.content}`).not.toContain(
        '전체보기'
      );
    }
  });

  it('long comment keeps full untruncated text', async () => {
    const repo = new HumorunivImpl(fixtureClient({ 'read.html': read('pds_1419653.html') }));

    const detail = await repo.fetchDetail('1419653');

    const long = firstWhere(detail.comments, 'comment', (c) => c.id === 515532327);
    expect(long.author).toBe('doksoori4');
    expect(long.content.startsWith('내가 썼던 글')).toBe(true);
    expect(
      long.content.length,
      `comment_more text must be complete, got: ${long.content}`
    ).toBeGreaterThan(500);
  });

  it('short comment strips trailing expander dots', async () => {
    const repo = new HumorunivImpl(fixtureClient({ 'read.html': read('pds_1419653.html') }));

    const detail = await repo.fetchDetail('1419653');

    const short = firstWhere(detail.comments, 'comment', (c) => c.id === 515531624);
    expect(short.author).toBe('포브스선정이딸');
    expect(short.content).toBe('어시..발?');
  });

  it('comment image markup stays out of content text', async () => {
    const repo = new HumorunivImpl(fixtureClient({ 'read.html': read('pds_1419653.html') }));

    const detail = await repo.fetchDetail('1419653');

    const withImage = firstWhere(detail.comments, 'comment', (c) => c.id === 515500234);
    expect(withImage.content).toContain('노브레인형님');
    expect(withImage.content).not.toContain('comment_crop');
    expect(withImage.content).not.toContain('gif');
  });
});

describe('HumorunivImpl.fetchDetail reply-count badge + replies', () => {
  // Since the 2026-08 redesign the reply-count badge `span.comment_num`
  // ("[N]") is nested INSIDE `.comment_more`, and reply `li`s
  // (`sub_comm_bt`) sit after a malformed double `</li>` close.
  it('reply-count badge [N] is stripped from parent content', async () => {
    const repo = new HumorunivImpl(fixtureClient({ 'read.html': read('pds_1419653.html') }));

    const detail = await repo.fetchDetail('1419653');

    for (const c of detail.comments) {
      expect(
        /\[\d+\]/.test(c.content),
        `comment by "${c.author}" leaked reply badge: ${c.content}`
      ).toBe(false);
    }

    const badge = firstWhere(detail.comments, 'comment', (c) => c.id === 515531716);
    expect(badge.author).toBe('짤방댓글러');
    expect(badge.content.startsWith('락덕후들이')).toBe(true);
  });

  it('nested replies attach to parent, not dropped', async () => {
    const repo = new HumorunivImpl(fixtureClient({ 'read.html': read('pds_1419653.html') }));

    const detail = await repo.fetchDetail('1419653');

    const parent = firstWhere(detail.comments, 'comment', (c) => c.id === 515500234);
    expect(
      parent.replies.length,
      `parent 515500234 must keep its sub_comm_bt replies; got ${parent.replies.length}`
    ).toBeGreaterThan(0);
    expect(parent.replies.map((r) => r.author)).toContain('개똥이아부지');
    for (const reply of parent.replies) {
      expect(reply.content).not.toContain('전체보기');
      expect(reply.content).not.toContain('[');
    }
  });
});

describe('HumorunivImpl.fetchDetail video thumbnail synthesis', () => {
  // Thumbnail-less VideoBlocks render as a permanent white circlePlay
  // placeholder in the feed carousel. humoruniv serves session-free
  // posters via timg.humoruniv.com/thumb.php?url=<media>, so the parser
  // must synthesize one whenever a video ships without its own poster.
  it('body VideoBlocks get a synthesized timg poster', async () => {
    const repo = new HumorunivImpl(fixtureClient({ 'read.html': read('pds_1419653.html') }));

    const detail = await repo.fetchDetail('1419653');

    const videos = videoBlocks(detail.contentBlocks);
    expect(videos.length, 'fixture must contain a video').toBeGreaterThan(0);
    for (const v of videos) {
      expect(
        v.thumbnailUrl?.startsWith('https://timg.humoruniv.com/thumb.php?url='),
        `video ${v.url} has no synthesized poster`
      ).toBe(true);
    }
    expect(
      videos.some((v) => v.thumbnailUrl === `https://timg.humoruniv.com/thumb.php?url=${v.url}`),
      'at least one poster must be synthesized (not pre-existing)'
    ).toBe(true);
  });

  it('comment VideoBlocks get a synthesized timg poster', async () => {
    const repo = new HumorunivImpl(fixtureClient({ 'read.html': read('pds_1415455.html') }));

    const detail = await repo.fetchDetail('1415455');

    const commentVideos = detail.comments.flatMap((c) => videoBlocks(c.mediaBlocks));
    expect(commentVideos.length, 'fixture has comment mp4s').toBeGreaterThan(0);
    for (const v of commentVideos) {
      expect(
        v.thumbnailUrl?.startsWith('https://timg.humoruniv.com/thumb.php?url='),
        `comment video ${v.url} has no synthesized poster`
      ).toBe(true);
    }
  });
});

describe('HumorunivImpl.fetchDetail url_enc session thumbs (1422694)', () => {
  // Body mp4 thumbs ship as `thumb.php?url_enc=<session-token>` images.
  // Left in, the token image becomes a dead first carousel page (white
  // retry card) and the video keeps an expiring poster. The scanner must
  // drop both so the carousel is [real photo, video(synthesized poster)].
  it('url_enc images never reach imageUrls or blocks', async () => {
    const repo = new HumorunivImpl(fixtureClient({ 'read.html': read('pds_1422694.html') }));

    const detail = await repo.fetchDetail('1422694');

    for (const url of detail.imageUrls) {
      expect(url, `session thumb leaked into imageUrls: ${url}`).not.toContain('url_enc=');
    }
    for (const block of detail.contentBlocks) {
      if (block.type === 'image') {
        expect(block.url).not.toContain('url_enc=');
      }
    }
  });

  it('carousel media is exactly one webp photo + one video with poster', async () => {
    const repo = new HumorunivImpl(fixtureClient({ 'read.html': read('pds_1422694.html') }));

    const detail = await repo.fetchDetail('1422694');

    expect(detail.imageUrls).toHaveLength(1);
    expect(detail.imageUrls[0]).toContain(
      'e_s02d384002_4451848a5446823511254c0de5c803fe529e8f9d.webp'
    );

    const videos = videoBlocks(detail.contentBlocks);
    expect(videos).toHaveLength(1);
    expect(videos[0].url).toContain('e_s02d384001_8de4aca03a6231489ab7fb65899fc6a4e6dcc796.mp4');
    expect(videos[0].thumbnailUrl, 'poster must be synthesized, not a session token').toBe(
      `https://timg.humoruniv.com/thumb.php?url=${videos[0].url}`
    );
  });
});

describe('HumorunivImpl.fetchDetail comment gif→mp4 expand divs (1427341)', () => {
  // Cookie'd requests (the app persists a cookie jar) re-ship comment
  // GIFs as comment_mp4_expand divs pointing at down-mp4.humoruniv.com
  // conversions. Those must stay in the comment's mediaBlocks and never
  // leak into the post-body carousel as a second VideoBlock page.
  it('body carousel is exactly one video, no comment mp4 leak', async () => {
    const repo = new HumorunivImpl(fixtureClient({ 'read.html': read('pds_1427341.html') }));

    const detail = await repo.fetchDetail('1427341');

    expect(detail.imageUrls).toHaveLength(0);

    const videos = videoBlocks(detail.contentBlocks);
    expect(videos).toHaveLength(1);
    expect(videos[0].url).toContain('a_wd7807a001_ffd59b4fa4ff837a57e1222283636727d4fad02b.mp4');
    expect(videos[0].thumbnailUrl).toBe(
      `https://timg.humoruniv.com/thumb.php?url=${videos[0].url}`
    );
  });

  it('comment gif→mp4 stays in comment mediaBlocks', async () => {
    const repo = new HumorunivImpl(fixtureClient({ 'read.html': read('pds_1427341.html') }));

    const detail = await repo.fetchDetail('1427341');

    const comment = firstWhere(detail.comments, 'comment', (c) => c.id === 516726485);
    const commentVideos = videoBlocks(comment.mediaBlocks);
    expect(commentVideos).toHaveLength(1);
    expect(commentVideos[0].url).toContain('down-mp4.humoruniv.com/f4/f4213bc915806d0a');
  });
});

describe('HumorunivImpl.fetchLatest pagination (pg is 0-based)', () => {
  // The live pager maps [1] -> pg=0, so a tokenless fetch must hit pg=0
  // (the real first page); starting at pg=1 silently skipped the newest
  // posts. The token chain must also stop at the last pager page instead
  // of requesting one empty page beyond it.
  it('tokenless fetch requests pg=0, not pg=1', async () => {
    const client = recordingClient();
    const repo = new HumorunivImpl(client);

    const result = await repo.fetchLatest();

    expect(client.get).toHaveBeenCalledTimes(1);
    expect(client.get.mock.calls[0][0]).toContain('pg=0');
    expect(result.items).toHaveLength(1);
  });

  it('token chain advances then stops at the last page', async () => {
    const repo = new HumorunivImpl(recordingClient());

    const first = await repo.fetchLatest();
    expect(first.pageToken).toBe('1');

    const second = await repo.fetchLatest({ pageToken: '1' });
    expect(second.pageToken).toBe('2');

    const last = await repo.fetchLatest({ pageToken: '2' });
    expect(last.pageToken).toBeNull();
  });
});

describe('HumorunivImpl.fetchDetail comment autolink images (1426857)', () => {
  // Comment images are autolink `<a href=url>url</a>` markup without any
  // `<img>` tag; they must surface as media blocks and the raw URL text
  // must not leak into comment content.
  it('comment autolink images become ImageBlocks', async () => {
    const repo = new HumorunivImpl(fixtureClient({ 'number=1426857': read('pds_1426857.html') }));

    const detail = await repo.fetchDetail('1426857');
    const comment = firstWhere(detail.comments, 'comment', (c) => c.id === 516655017);

    const images = imageBlocks(comment.mediaBlocks);
    expect(images).toHaveLength(3);
    expect(images.every((i) => i.url.includes('down.humoruniv.com'))).toBe(true);
    expect(images[0].url).toContain('worldcup_15253');
    expect(images[1].url).toContain('r_rec7e5a001');
    expect(images[2].url).toContain('worldcup_15438');
  });

  it('comment content strips raw image URL text', async () => {
    const repo = new HumorunivImpl(fixtureClient({ 'number=1426857': read('pds_1426857.html') }));

    const detail = await repo.fetchDetail('1426857');
    const comment = firstWhere(detail.comments, 'comment', (c) => c.id === 516655017);

    expect(comment.content).not.toContain('down.humoruniv.com');
  });
});

describe('HumorunivImpl data/pds attachment storage migration (1428508)', () => {
  // 2026-10: new `hwiparambbs/data/pds/a_*` uploads 404 on
  // down.humoruniv.com; the canonical file now lives on the webp CDN at
  // `down-webp.humoruniv.com/<hash[0:2]>/<hash>.webp` (also the img src
  // the page itself ships). The dead original survives only in
  // `img_file_url` and thumb.php params, so every URL of that shape —
  // feed thumbnails, body blocks, imageUrls — must be rewritten.
  const deadOriginal =
    'https://down.humoruniv.com/hwiparambbs/data/pds/' +
    'a_wb96707001_62616c6a5e766c82782b378487c0d217219306f1.png';
  const webpCdn =
    'https://down-webp.humoruniv.com/' + '62/62616c6a5e766c82782b378487c0d217219306f1.webp';

  it('body attachment urls are rewritten to the webp CDN', async () => {
    const repo = new HumorunivImpl(fixtureClient({ 'read.html': read('pds_1428508.html') }));

    const detail = await repo.fetchDetail('1428508');

    expect(detail.imageUrls).toContain(webpCdn);
    expect(detail.imageUrls).not.toContain(deadOriginal);

    const images = imageBlocks(detail.contentBlocks);
    expect(images.length, 'fixture must contain an image').toBeGreaterThan(0);
    for (const img of images) {
      expect(
        img.url.includes('down.humoruniv.com/hwiparambbs/data/pds/'),
        `dead attachment url leaked: ${img.url}`
      ).toBe(false);
    }
    expect(
      images.some((i) => i.url === webpCdn),
      'img_file_url must map to the webp CDN file'
    ).toBe(true);
  });

  it('data/pds list thumb unwraps to the webp CDN', async () => {
    const listHtml = `
<html><body>
<div class="post_item"><a class="post_link" data-number="1428508"
 href="read.html?table=pds&amp;number=1428508">
<table><tr>
<td><img class="img" src="https://timg.humoruniv.com/thumb.php?url=${deadOriginal}?SIZE=120x90"></td>
<td><span class="link_hover">title</span></td>
</tr></table></a></div>
<div id="pgnum"><a class="def" href="list.html?table=pds&amp;pg=0">1</a></div>
</body></html>
`;
    const repo = new HumorunivImpl(fixtureClient({ 'list.html': listHtml }));

    const result = await repo.fetchLatest();

    expect(result.items[0].thumbnailUrl).toBe(webpCdn);
  });

  it('editor upload thumbs keep the original host', async () => {
    const editorOriginal =
      'https://down.humoruniv.com/hwiparambbs/data/editor/pdswait/' +
      'e_sb269e5003_aaf59e6fe748ba115415bfb75e6ce3ad28a2a169.jpg';
    const listHtml = `
<html><body>
<div class="post_item"><a class="post_link" data-number="1428508"
 href="read.html?table=pds&amp;number=1428508">
<table><tr>
<td><img class="img" src="https://timg.humoruniv.com/thumb.php?url=${editorOriginal}?SIZE=120x90"></td>
<td><span class="link_hover">title</span></td>
</tr></table></a></div>
<div id="pgnum"><a class="def" href="list.html?table=pds&amp;pg=0">1</a></div>
</body></html>
`;
    const repo = new HumorunivImpl(fixtureClient({ 'list.html': listHtml }));

    const result = await repo.fetchLatest();

    expect(result.items[0].thumbnailUrl).toBe(editorOriginal);
  });
});

describe('HumorunivImpl native webp uploads stay in place (1428549)', () => {
  // Native webp (and mp4) attachments exist only on the original
  // down.humoruniv.com host — the webp CDN 404s for them — so the
  // png/jpg propagation rewrite must never touch them.
  const webpOriginal =
    'https://down.humoruniv.com/hwiparambbs/data/pds/' +
    'a_w776d7a001_11eda84ef82bd1667e3dd6ff3b503ba8b038ae76.webp';

  it('body native webp url is not rewritten to the CDN', async () => {
    const repo = new HumorunivImpl(fixtureClient({ 'read.html': read('pds_1428549.html') }));

    const detail = await repo.fetchDetail('1428549');

    const images = imageBlocks(detail.contentBlocks);
    expect(images.length, 'fixture must contain an image').toBeGreaterThan(0);
    for (const img of images) {
      expect(
        img.url.startsWith('https://down-webp.humoruniv.com/'),
        `native upload wrongly rewritten: ${img.url}`
      ).toBe(false);
    }
    expect(
      images.some((i) => i.url === webpOriginal),
      'webp original must survive as-is'
    ).toBe(true);
    expect(detail.imageUrls).toContain(webpOriginal);
  });

  it('native webp list thumb keeps the original host', async () => {
    const listHtml = `
<html><body>
<div class="post_item"><a class="post_link" data-number="1428549"
 href="read.html?table=pds&amp;number=1428549">
<table><tr>
<td><img class="img" src="https://timg.humoruniv.com/thumb.php?url=${webpOriginal}?SIZE=120x90"></td>
<td><span class="link_hover">title</span></td>
</tr></table></a></div>
<div id="pgnum"><a class="def" href="list.html?table=pds&amp;pg=0">1</a></div>
</body></html>
`;
    const repo = new HumorunivImpl(fixtureClient({ 'list.html': listHtml }));

    const result = await repo.fetchLatest();

    expect(result.items[0].thumbnailUrl).toBe(webpOriginal);
  });
});

describe('HumorunivImpl.fetchDetail hidden attachment toolbox', () => {
  it('strips ZIP/filename/origin noise from the body', async () => {
    const repo = new HumorunivImpl(fixtureClient({ 'number=1429732': read('pds_1429732.html') }));

    const detail = await repo.fetchDetail('1429732');

    const texts = textBlocks(detail.contentBlocks).map((b) => b.text);
    expect(texts, `body has no real prose; found: ${texts}`).toHaveLength(0);

    const images = imageBlocks(detail.contentBlocks);
    expect(
      images.length,
      'only the three body images may remain; download-list thumbs and ' +
        `duplicates must be gone (${images.map((i) => i.url).join(', ')})`
    ).toBe(3);
    for (const img of images) {
      expect(img.url).toContain('data/editor/pdswait/');
    }
  });

  it('body images survive with editor URLs', async () => {
    const repo = new HumorunivImpl(fixtureClient({ 'number=1429732': read('pds_1429732.html') }));

    const detail = await repo.fetchDetail('1429732');

    expect(detail.imageUrls, 'img_file_url override must stay the canonical URL').toContain(
      'https://down.humoruniv.com/hwiparambbs/data/editor/pdswait/' +
        'e_e2b4c0b001_fe197ae4ad97377492114f6fd788c49ab35344bd.png'
    );
  });
});
