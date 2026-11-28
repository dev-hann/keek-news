import { Http } from '@gyo-community/http';
import {
  registeredCommunityIds,
  type CommunityId,
  type RegisteredCommunityId,
} from '../model/community';
import { BookmarkImpl } from '../repository/bookmark/bookmark_impl';
import { BlockedImageImpl } from '../repository/blocked_image/blocked_image_impl';
import { HumorunivImpl } from '../repository/community/humoruniv/humoruniv_impl';
import type { CommunityRepo } from '../repository/community/community_repo';
import { FeedImpl } from '../repository/feed/feed_impl';
import { BlockImageUseCase } from '../use_case/block_image_use_case';
import { BookmarkUseCase } from '../use_case/bookmark_use_case';
import { FeedUseCase } from '../use_case/feed_use_case';
import { browserHeaders, desktopUserAgent, mobileUserAgent } from './community_headers';
import { BrowserLocalStorageService } from './browser_local_storage_service';
import { HtmlClient, type HtmlClientOptions } from './html_client';
import { FlutterImageHashService } from './image_hash_service';

function pageClient(
  userAgent: string,
  baseUrl: string,
  referer: string,
  encoding: string,
  jar?: string
): HtmlClientOptions {
  return {
    baseUrl,
    encoding,
    ...(jar ? { jar } : {}),
    headers: { 'User-Agent': userAgent, ...browserHeaders, Referer: referer },
  };
}

/** How each community's pages are read. */
export const htmlClientOptions: Record<CommunityId, HtmlClientOptions> = {
  humoruniv: pageClient(
    mobileUserAgent,
    'https://m.humoruniv.com',
    'https://m.humoruniv.com/board/pds/',
    // humoruniv moved from EUC-KR to UTF-8 in 2026-10; decoding as EUC-KR garbles every Korean character.
    'utf-8',
    'humoruniv'
  ),
  todayhumor: pageClient(
    desktopUserAgent,
    'https://www.todayhumor.co.kr',
    'https://www.todayhumor.co.kr/board/humorbest.php',
    'utf-8',
    'todayhumor'
  ),
  ppomppu: pageClient(
    desktopUserAgent,
    'https://www.ppomppu.co.kr',
    'https://www.ppomppu.co.kr/zboard/zboard.php?id=humor',
    'euc-kr',
    'ppomppu'
  ),
  dogdrip: pageClient(
    desktopUserAgent,
    'https://www.dogdrip.net',
    'https://www.dogdrip.net/index.php?mid=dogdrip',
    'utf-8',
    'dogdrip'
  ),
  fmkorea: pageClient(
    desktopUserAgent,
    'https://www.fmkorea.com',
    'https://www.fmkorea.com/index.php?mid=humor',
    'utf-8',
    'fmkorea'
  ),
  // bobaedream declares <meta charset=utf-8> and has served UTF-8 for years.
  bobaedream: pageClient(
    desktopUserAgent,
    'https://www.bobaedream.co.kr',
    'https://www.bobaedream.co.kr/list?code=humor',
    'utf-8'
  ),
  ruliweb: pageClient(
    desktopUserAgent,
    'https://bbs.ruliweb.com',
    'https://bbs.ruliweb.com/best/humor',
    'utf-8'
  ),
  natepann: pageClient(
    desktopUserAgent,
    'https://pann.nate.com',
    'https://pann.nate.com/talk',
    'utf-8'
  ),
};

let relay: Http | undefined;

/** The one relay of the app, made the first time a page is fetched. */
function http(): Http {
  relay ??= new Http();
  return relay;
}

/** Reads the pages of a community. */
export function htmlClient(id: CommunityId): HtmlClient {
  return new HtmlClient(http(), htmlClientOptions[id]);
}

let repos: Record<RegisteredCommunityId, CommunityRepo> | undefined;

/**
 * Every community the app serves, by id. A community joins the app here and
 * in `registeredCommunityIds` of model/community.ts; the compiler wants both.
 * Made the first time a use case asks for it: a repository holds the relay,
 * which exists only in the WebView.
 */
export function communityRepos(): Record<RegisteredCommunityId, CommunityRepo> {
  repos ??= { humoruniv: new HumorunivImpl(htmlClient('humoruniv')) };
  return repos;
}

let feed: FeedUseCase | undefined;

/** The one feed use case of the app, made the first time a provider asks for it. */
export function feedUseCase(): FeedUseCase {
  feed ??= new FeedUseCase(
    communityRepos(),
    new FeedImpl(new BrowserLocalStorageService(), registeredCommunityIds)
  );
  return feed;
}

let bookmarks: BookmarkUseCase | undefined;

/** The one bookmark use case of the app, made the first time a screen asks for it. */
export function bookmarkUseCase(): BookmarkUseCase {
  bookmarks ??= new BookmarkUseCase(new BookmarkImpl(new BrowserLocalStorageService()));
  return bookmarks;
}

let blockImage: BlockImageUseCase | undefined;

/** The one blocklist use case of the app, made the first time a screen asks for it. */
export function blockImageUseCase(): BlockImageUseCase {
  blockImage ??= new BlockImageUseCase(
    new BlockedImageImpl(new BrowserLocalStorageService()),
    new FlutterImageHashService(http())
  );
  return blockImage;
}
