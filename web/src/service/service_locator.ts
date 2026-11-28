import { Http } from '@gyo-community/http';
import type { CommunityId } from '../model/community';
import { browserHeaders, desktopUserAgent, mobileUserAgent } from './community_headers';
import { HtmlClient, type HtmlClientOptions } from './html_client';

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
