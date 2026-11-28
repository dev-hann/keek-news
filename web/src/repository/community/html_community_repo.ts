import type { CommunityId } from '../../model/community';
import type { FeedItem } from '../../model/feed_item';
import type { LoadedPostDetail } from '../../model/post_detail';
import type { HtmlClient } from '../../service/html_client';
import { parseHtml, tryParseInt } from '../../service/html_service';
import type { CommunityListResult, CommunityRepo } from './community_repo';

/** A community read from the HTML of its list and post pages. */
export abstract class HtmlCommunityRepo implements CommunityRepo {
  protected readonly htmlClient: Pick<HtmlClient, 'get'>;

  constructor(htmlClient: Pick<HtmlClient, 'get'>) {
    this.htmlClient = htmlClient;
  }

  abstract get communityId(): CommunityId;

  abstract fetchDetail(id: string): Promise<LoadedPostDetail>;

  abstract listPath(page: string): string;

  abstract listRowSelector(): string;

  abstract parseListRow(row: Element): FeedItem | null;

  abstract get listPageSize(): number;

  /** Page token `fetchLatest` uses when called without one. Boards are 1-based except humoruniv, whose `pg` is 0-based. */
  get firstPageToken(): string {
    return '1';
  }

  computeNextPageToken(_doc: Document, currentPage: string, items: FeedItem[]): string | null {
    if (items.length < this.listPageSize) return null;
    return String((tryParseInt(currentPage) ?? 0) + 1);
  }

  /** Builds a Date from the first match of `pattern` on `text`. Capture groups map to year, month, day, then optionally hour/minute/second; missing groups become 0. Two-digit years resolve against 2000 when `year2` is set. Returns null when the pattern does not match. */
  parseDatePattern(
    text: string,
    pattern: RegExp,
    { year2 = false }: { year2?: boolean } = {}
  ): Date | null {
    const match = pattern.exec(text);
    if (match === null) return null;
    const group = (index: number): number =>
      match[index] === undefined ? 0 : Number(match[index]);
    return new Date(
      year2 ? 2000 + group(1) : group(1),
      group(2) - 1,
      group(3),
      group(4),
      group(5),
      group(6)
    );
  }

  async fetchLatest(options?: { pageToken?: string | null }): Promise<CommunityListResult> {
    const page = options?.pageToken ?? this.firstPageToken;
    const html = await this.htmlClient.get(this.listPath(page));
    const doc = parseHtml(html);
    const items = [...doc.querySelectorAll(this.listRowSelector())]
      .map((row) => this.parseListRow(row))
      .filter((item): item is FeedItem => item !== null);
    return { items, pageToken: this.computeNextPageToken(doc, page, items) };
  }
}
