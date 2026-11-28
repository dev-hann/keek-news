import type { Comment } from '../../../model/comment';
import { communityBaseUrls, type CommunityId } from '../../../model/community';
import type { ContentBlock, ImageBlock, VideoBlock } from '../../../model/content_block';
import type { ContentScanResult } from '../../../model/content_scan_result';
import type { FeedItem } from '../../../model/feed_item';
import type { LoadedPostDetail } from '../../../model/post_detail';
import { scanContentCompact, scanContentFull } from '../../../service/content_scanner';
import {
  attrOf,
  extractBracketedInt,
  extractNumber,
  parseHtml,
  queryFirst,
  statOf,
  statOfAny,
  textOf,
  textOfAny,
  tryParseInt,
} from '../../../service/html_service';
import { classify } from '../../../service/media_classifier';
import { HtmlCommunityRepo } from '../html_community_repo';

/** The 웃긴자료 (`pds`) board of humoruniv. */
export class HumorunivImpl extends HtmlCommunityRepo {
  override get communityId(): CommunityId {
    return 'humoruniv';
  }

  /** m.humoruniv.com `pg` is 0-based: the site pager maps [1] -> pg=0. */
  override get firstPageToken(): string {
    return '0';
  }

  listPath(page: string): string {
    return `/board/list.html?table=pds&pg=${tryParseInt(page) ?? 0}`;
  }

  listRowSelector(): string {
    return 'div.post_item a.post_link';
  }

  override get listPageSize(): number {
    return 0;
  }

  computeNextPageToken(doc: Document, currentPage: string): string | null {
    const page = tryParseInt(currentPage) ?? 0;
    const totalPage = extractTotalPage(doc);
    return page < totalPage - 1 ? String(page + 1) : null;
  }

  async fetchDetail(id: string): Promise<LoadedPostDetail> {
    const html = await this.htmlClient.get(`/board/read.html?table=pds&number=${id}`);
    const doc = parseHtml(html);

    // read.html ships hidden UI after the body: `#download_all_span`
    // ("ZIP 파일 다운로드") and the `#btn_nemo_expand_all` "원본" chip.
    // Neither ever carries media, so they are dropped doc-wide. This also
    // blinds the doc-wide download.php fallback to nothing — their hrefs are
    // download_all.php, never matched.
    for (const el of doc.querySelectorAll('#download_all_span, #btn_nemo_expand_all')) {
      el.remove();
    }

    const contentEl = findContentContainer(doc);
    let scanResult: ContentScanResult;
    if (contentEl !== null) {
      // `#list_download_div` (per-file rows "001.png"… plus the 베스트 댓글
      // 스크린샷 block) leaks its filename text when the malformed page nests
      // it inside the body container. Inside, its download.php links are
      // duplicates of inline body images anyway. Outside — the only place
      // native webp/mp4 uploads expose their media — it must survive so the
      // doc-wide fallback can still collect it (1428549).
      for (const el of contentEl.querySelectorAll('#list_download_div')) el.remove();
      scanResult = scanContentFull(doc, contentEl);
    } else {
      scanResult = { blocks: [], imageUrls: [] };
    }

    const postDate = extractDate(doc);

    return {
      status: 'loaded',
      id: tryParseInt(id) ?? 0,
      community: 'humoruniv',
      title: extractTitle(doc),
      author: extractAuthor(doc),
      date: postDate,
      contentBlocks: scanResult.blocks.map(rewriteAttachmentBlock).map(withSynthesizedVideoThumb),
      imageUrls: scanResult.imageUrls.map(rewriteAttachmentUrl),
      recommendCount: extractRecommendCount(doc),
      notRecommendCount: extractNotRecommendCount(doc),
      viewCount: extractViewCount(doc),
      commentCount: extractCommentCount(doc),
      comments: extractComments(doc, postDate),
    };
  }

  parseListRow(anchor: Element): FeedItem | null {
    const number = anchor.getAttribute('data-number') ?? '';
    const id = tryParseInt(number) ?? 0;
    if (id === 0) return null;

    const href = anchor.getAttribute('href') ?? '';
    const url = buildPostUrl(href);
    const title = textOf(anchor.querySelector('span.link_hover'));
    const author = textOf(anchor.querySelector('span.hu_nick_txt'));

    const blk = anchor.querySelector('span.blk');
    const recommendCount = statOf(blk, 'span.ok_num');
    const commentCount = statOf(blk, 'span.comment_num');
    const viewCount = extractViewCountFromBlk(blk);

    const thumbnailUrl = extractThumbnail(anchor);

    return {
      community: 'humoruniv',
      id: String(id),
      title,
      url,
      ...(author === '' ? {} : { author }),
      recommendCount,
      commentCount,
      viewCount,
      ...(thumbnailUrl === '' ? {} : { thumbnailUrl }),
    };
  }
}

function extractViewCountFromBlk(blk: Element | null): number {
  if (blk === null) return 0;
  for (const extra of blk.querySelectorAll('span.extra')) {
    const num = extractNumber(extra.textContent);
    if (num > 0) return num;
  }
  return 0;
}

function extractThumbnail(anchor: Element): string {
  const img = anchor.querySelector('td img.img');
  if (img === null) return '';
  const src = attrOf(img, 'src') ?? '';
  if (src === '' || src.includes('no_image')) return '';
  const normalized = src.startsWith('//') ? `https:${src}` : src;
  return fullSizeFromThumb(normalized);
}

// humoruniv publishes non-webp board attachments
// (`hwiparambbs/data/pds/a_<id>_<hash>.{png,jpg}`) to the webp CDN
// (`down-webp.humoruniv.com/<hash[0:2]>/<hash>.webp`) immediately, but
// the original on down.humoruniv.com only appears after a propagation
// delay — fresh posts 404 there for a while (verified 2026-10: six
// list attachments were 404 at fetch time and 200 an hour later).
// Rewriting png/jpg to the CDN covers that window and stays correct
// afterwards (both copies live).
// Native webp and mp4 uploads exist ONLY on the original host — the
// CDN 404s for them — so they must never be rewritten. Editor uploads
// (`data/editor/pdswait/e_*`) and comment files (`data/comment/*`)
// also resolve in place and pass through untouched.
const legacyAttachmentPattern =
  /^https?:\/\/down\.humoruniv\.com\/hwiparambbs\/data\/pds\/a_[0-9a-z]+_([0-9a-f]{40})\.(?:png|jpe?g)$/i;

function rewriteAttachmentUrl(url: string): string {
  const match = legacyAttachmentPattern.exec(url);
  if (match === null) return url;
  const hash = match[1];
  return `https://down-webp.humoruniv.com/${hash.slice(0, 2)}/${hash}.webp`;
}

/** The block's `thumbnailUrl` rewritten, as a property list to spread: absent stays absent. */
function rewrittenThumbnail(block: ImageBlock | VideoBlock): Pick<ImageBlock, 'thumbnailUrl'> {
  return block.thumbnailUrl === undefined
    ? {}
    : { thumbnailUrl: rewriteAttachmentUrl(block.thumbnailUrl) };
}

function rewriteAttachmentBlock(block: ContentBlock): ContentBlock {
  switch (block.type) {
    case 'image':
      return { type: 'image', url: rewriteAttachmentUrl(block.url), ...rewrittenThumbnail(block) };
    case 'video':
      return { ...block, ...rewrittenThumbnail(block) };
    default:
      return block;
  }
}

function fullSizeFromThumb(url: string): string {
  const match = /thumb\.php\?url=([^&]+)/.exec(url);
  if (match === null) return url;
  let original = decodeURIComponent(match[1]);
  const sizeIdx = original.indexOf('?SIZE=');
  if (sizeIdx !== -1) original = original.slice(0, sizeIdx);
  if (classify(original) === 'video') {
    const outerSizeIdx = url.indexOf('?SIZE=');
    return outerSizeIdx !== -1 ? url.slice(0, outerSizeIdx) : url;
  }
  return rewriteAttachmentUrl(original);
}

function buildPostUrl(href: string): string {
  if (href === '') return '';
  let uri: URL;
  try {
    uri = new URL(href, communityBaseUrls.humoruniv);
  } catch {
    return href;
  }
  const table = uri.searchParams.get('table');
  const number = uri.searchParams.get('number');
  if (table !== null && number !== null) {
    return `/board/read.html?table=${table}&number=${number}`;
  }
  return href;
}

function extractTotalPage(doc: Document): number {
  const links = doc.querySelectorAll('#pgnum a.def');
  if (links.length === 0) return 0;
  let maxPage = 0;
  for (const a of links) {
    const href = a.getAttribute('href') ?? '';
    const match = /pg=(\d+)/.exec(href);
    if (match !== null) {
      const p = Number(match[1]);
      if (p > maxPage) maxPage = p;
    }
  }
  return maxPage + 1;
}

function extractTitle(doc: Document): string {
  // The subject header carries the displayed title. Pages from the
  // header-less `#read_view_wrap` template (fixture 1429732) only expose it
  // through <head><title>, which sits outside `doc.body`.
  const subject = textOfAny(doc.body, ['#read_subject_div h2 a']);
  if (subject !== '') return subject;
  return textOf(doc.querySelector('title'));
}

function extractAuthor(doc: Document): string {
  return textOfAny(doc.body, [
    '#read_profile_td .hu_nick_txt',
    '.hu_nick_txt',
    '.read_author',
    '.author_name',
    '.nick_name',
  ]);
}

function extractDate(doc: Document): Date {
  const descEl = doc.querySelector('#read_profile_desc');
  if (descEl === null) return new Date(0);
  for (const el of descEl.querySelectorAll('.etc')) {
    const text = (el.textContent ?? '').trim();
    if (text.startsWith('작성')) {
      return tryParsePostDate(text.replace('작성', '').trim()) ?? new Date(0);
    }
  }
  return new Date(0);
}

const postDatePattern = /^(\d{4})-(\d{2})-(\d{2})(?: (\d{2}):(\d{2})(?::(\d{2}))?)?$/;

/**
 * Dart's `DateTime.tryParse` on the `작성` line: `YYYY-MM-DD[ HH:MM[:SS]]` as local
 * time, null for any other shape. Out-of-range components roll over into the next
 * larger one, as they do there ("2026-02-30" is March 2), so they are not rejected.
 */
function tryParsePostDate(text: string): Date | null {
  const match = postDatePattern.exec(text);
  if (match === null) return null;
  return new Date(
    Number(match[1]),
    Number(match[2]) - 1,
    Number(match[3]),
    Number(match[4] ?? 0),
    Number(match[5] ?? 0),
    Number(match[6] ?? 0)
  );
}

function findContentContainer(doc: Document): Element | null {
  return queryFirst(doc.body, [
    '.body_editor',
    '.daum-wm-content',
    '.view_content',
    '.board-contents',
    '[itemprop="articleBody"]',
  ]);
}

function extractRecommendCount(doc: Document): number {
  return statOfAny(doc.body, [
    '#ok_div',
    '.ok_div',
    '#ok_count',
    '.recommend_count',
    '[id^="ok_div"]',
  ]);
}

function extractNotRecommendCount(doc: Document): number {
  return statOfAny(doc.body, [
    '#not_ok_span',
    '.not_ok_span',
    '#not_ok_count',
    '.not_recommend_count',
    '[id^="not_ok"]',
  ]);
}

function extractViewCount(doc: Document): number {
  const descEl = doc.querySelector('#read_profile_desc');
  if (descEl === null) return 0;
  for (const span of descEl.querySelectorAll('.etc')) {
    const img = span.querySelector('img[src*="ic_view"]');
    if (img === null) continue;
    return extractNumber(span.textContent);
  }
  return 0;
}

function extractCommentCount(doc: Document): number {
  const hit = queryFirst(doc.body, [
    '#content_info h2 .comment_num',
    'h2 .comment_num',
    '.comment_num',
    '#comment_count',
    '[id^="comment_count"]',
  ]);
  if (hit === null) return 0;
  return extractBracketedInt(hit.textContent);
}

function extractComments(doc: Document, postDate: Date): Comment[] {
  const comments: Comment[] = [];

  for (const item of doc.querySelectorAll('#comment_best_wrap .best_li')) {
    comments.push(parseComment(item, { isBest: true, postDate }));
  }

  // humoruniv closes each parent <li> twice before its reply <li>s, so
  // the html5 parser detaches replies from their parent in the DOM.
  // Walk all comment <li>s in document order and attach each reply to
  // the nearest preceding non-reply comment instead.
  const replyElsByParent = new Map<number, Element[]>();
  for (const item of doc.querySelectorAll('li[id^="comment_li_"]')) {
    const isSub =
      item.classList.contains('sub_comm_bt') || item.getAttribute('name') === 'sub_comm_block';
    if (isSub) {
      const parentIndex = comments.length - 1;
      if (parentIndex >= 0) {
        const replies = replyElsByParent.get(parentIndex);
        if (replies === undefined) replyElsByParent.set(parentIndex, [item]);
        else replies.push(item);
      }
      continue;
    }
    comments.push(parseComment(item, { isBest: false, postDate }));
  }

  for (const [parentIndex, replyEls] of replyElsByParent) {
    comments[parentIndex] = {
      ...comments[parentIndex],
      replies: replyEls.map((el) => parseComment(el, { isBest: false, postDate })),
    };
  }

  return comments;
}

function parseComment(
  item: Element,
  { isBest, postDate }: { isBest: boolean; postDate: Date }
): Comment {
  // Best comments of long-nick users render a bare `.nick` with no inner
  // `.hu_nick_txt` wrapper.
  const author = textOfAny(item, ['.hu_nick_txt', '.nick']);

  const mediaBlocks: ContentBlock[] = [];
  const bodyEl = item.querySelector('.comment_body');
  if (bodyEl !== null) {
    mediaBlocks.push(
      ...scanContentCompact(bodyEl).map(rewriteAttachmentBlock).map(withSynthesizedVideoThumb)
    );
  }

  let content = '';
  if (bodyEl !== null) {
    // 2026-08 redesign: humoruniv dropped `.comment_text` and wraps
    // bodies in `.comment_more`; the sibling `.comment_more_btn`
    // ("...전체보기") is pure UI and must never reach content. The
    // reply-count badge `.comment_num` ("[4]") is nested INSIDE
    // `.comment_more`, so both must be stripped before reading text.
    const textEl = bodyEl.querySelector('.comment_text') ?? bodyEl.querySelector('.comment_more');
    const clone = (textEl ?? bodyEl).cloneNode(true) as Element;
    for (const el of clone.querySelectorAll(
      '.recomm_btn, .btn_move, .comment_num, .comment_thumb_notice, ' +
        '.comment_img_div, .comment_crop_wrap, .comment_crop_href, ' +
        '.comment_crop_href_mp4, .comment_file, .comment_more_btn'
    )) {
      el.remove();
    }
    removeMediaUrlAnchors(clone, mediaBlocks);
    content = (clone.textContent ?? '').trim();
  }

  let date = new Date(0);
  for (const el of item.querySelectorAll('.etc')) {
    const text = (el.textContent ?? '').trim();
    const parsed = parseCommentDate(text, postDate);
    if (parsed !== null) {
      date = parsed;
      break;
    }
  }

  let recommendCount = 0;
  const okSpan = item.querySelector('.o');
  if (okSpan !== null) {
    recommendCount = extractNumber(okSpan.textContent);
  }
  if (recommendCount === 0) {
    const rSpan = item.querySelector('.r');
    if (rSpan !== null) {
      recommendCount = extractNumber(rSpan.textContent);
    }
  }

  const idNum = extractNumber(item.id);

  return {
    id: idNum,
    author,
    content,
    date,
    recommendCount,
    isBest,
    mediaBlocks,
    replies: [],
  };
}

/** Comment images arrive as autolink `<a href=url>url</a>` where the URL doubles as the anchor text. Once the URL becomes a media block, the raw-URL anchor is a duplicate and must not leak into content text. Labeled links (text != href) are user-written and stay. */
function removeMediaUrlAnchors(root: Element, blocks: ContentBlock[]): void {
  const mediaUrls = new Set<string>();
  for (const block of blocks) {
    if (block.type === 'image' || block.type === 'video') mediaUrls.add(block.url);
  }
  if (mediaUrls.size === 0) return;
  for (const a of root.querySelectorAll('a')) {
    const href = a.getAttribute('href') ?? '';
    if ((a.textContent ?? '').trim() === href && mediaUrls.has(href)) a.remove();
  }
}

/** humoruniv exposes a session-free thumbnail proxy for any hosted media (same shape as og:image / file-list thumbs), so thumbnail-less videos can always get a poster instead of a bare placeholder in the feed. */
function withSynthesizedVideoThumb(block: ContentBlock): ContentBlock {
  if (block.type === 'video' && !block.thumbnailUrl) {
    return { ...block, thumbnailUrl: `https://timg.humoruniv.com/thumb.php?url=${block.url}` };
  }
  return block;
}

const commentDatePattern = /(?:(\d{4})-)?(\d{1,2})-(\d{1,2})(?:[^\d]*?(\d{1,2}):(\d{2}):(\d{2}))?/;

/** Extracts `YYYY-MM-DD [HH:MM:SS]` from humoruniv's noisy `.etc` text. Long-nick best comments drop the year (`MM-DD HH:MM:SS`); such a date is anchored to the post's year, rolling forward once when that would put the comment before the post was written. */
function parseCommentDate(text: string, postDate: Date): Date | null {
  const m = commentDatePattern.exec(text);
  if (m === null) return null;
  const year = tryParseInt(m[1] ?? '');
  const month = Number(m[2]);
  const day = Number(m[3]);
  const hour = tryParseInt(m[4] ?? '') ?? 0;
  const minute = tryParseInt(m[5] ?? '') ?? 0;
  const second = tryParseInt(m[6] ?? '') ?? 0;
  const postYear = postDate.getFullYear();
  if (year !== null) return new Date(year, month - 1, day, hour, minute, second);
  const inPostYear = new Date(postYear, month - 1, day, hour, minute, second);
  return inPostYear.getTime() < postDate.getTime()
    ? new Date(postYear + 1, month - 1, day, hour, minute, second)
    : inPostYear;
}
