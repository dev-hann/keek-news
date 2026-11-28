import { ImageOff, MoreHorizontal } from 'lucide-react';
import { useEffect, useMemo, useRef, useState, type UIEvent as ReactUIEvent } from 'react';
import { Button } from '../components/ui/button';
import { Skeleton } from '../components/ui/skeleton';
import type { VideoBlock } from '../model/content_block';
import type { FeedItemKey } from '../model/feed_item';
import { imageTarget, videoTarget, type MediaTarget } from '../model/media_target';
import { videoId } from '../model/video_id';
import { useLongPress } from '../utils/use_long_press';
import { InlineVideoPlayer } from './inline_video_player';

/** How long a pager must have stopped scrolling for the area to take its page's height. */
const SETTLE_AFTER = 250;

/** One page of the pager. A `poster` is a video from outside the community, of which only its poster can be shown. */
type Page =
  | { kind: 'image'; key: string; url: string; index: number }
  | { kind: 'video'; key: string; block: VideoBlock; blockIndex: number }
  | { kind: 'poster'; key: string; url: string; block: VideoBlock };

function targetOf(page: Page): MediaTarget {
  if (page.kind === 'image') return imageTarget(page.url);
  return videoTarget(page.block);
}

/** The pages of a post, its images first and then its videos. An outside embed with no poster gets no page. */
function pagesOf(images: string[], videos: VideoBlock[]): Page[] {
  const keys = new Map<string, number>();
  // A post can hold the same address twice: the key still tells the two pages apart.
  const key = (url: string): string => {
    const before = keys.get(url) ?? 0;
    keys.set(url, before + 1);
    return `${url}#${before}`;
  };
  return [
    ...images.map((url, index): Page => ({ kind: 'image', key: key(url), url, index })),
    ...videos.flatMap((block, blockIndex): Page[] => {
      if (videoTarget(block).kind !== 'external') {
        return [{ kind: 'video', key: key(block.url), block, blockIndex }];
      }
      // The web app has no player for an embed: its poster is a picture, or there is nothing to show.
      return block.thumbnailUrl === undefined
        ? []
        : [{ kind: 'poster', key: key(block.url), url: block.thumbnailUrl, block }];
    }),
  ];
}

interface FeedImageCarouselProps {
  /** The post the media belong to: it names each of its videos. */
  postKey: FeedItemKey;
  /** The images, in order. Blocked ones are left out before this is given. */
  images: string[];
  /** The videos, after the images. */
  videos: VideoBlock[];
  /** Opens the full-screen viewer on that image. */
  onOpenImage?: (index: number) => void;
  /** Opens the media action sheet for what the page shows: a long-press on it, or its ⋯ button. */
  onMore?: (target: MediaTarget) => void;
}

/**
 * The images and videos of a post, one page at a time, to swipe through.
 * Images come first, then videos; an embed from outside the community shows
 * its poster and nothing more.
 *
 * The area is as tall as the page shown, and moves to that height once the
 * pager has come to rest on the page (see `settled`). Each page is a box of its own shape, so a picture that is
 * still loading holds its place (square) and nothing moves under the reader.
 */
export function FeedImageCarousel({
  postKey,
  images,
  videos,
  onOpenImage,
  onMore,
}: FeedImageCarouselProps) {
  const pages = useMemo(() => pagesOf(images, videos), [images, videos]);
  const count = pages.length;
  const showing = count > 0;

  const scroller = useRef<HTMLDivElement>(null);
  const pageElements = useRef<(Element | null)[]>([]);
  const [page, setPage] = useState(0);
  /**
   * The page the pager has come to rest on. The area takes the height of
   * that page, not of the one passing by: resized under a finger that
   * swipes it, the Android WebView puts the scroll back to the start, and
   * the pager never reaches the next page.
   */
  const [settled, setSettled] = useState(0);
  const settleTimer = useRef<number | undefined>(undefined);
  const [heights, setHeights] = useState<number[]>([]);

  // The list can shrink under the pager, when an image is blocked: a page past its end is the last one.
  const shown = count === 0 ? 0 : Math.min(page, count - 1);
  if (shown !== page) setPage(shown);

  useEffect(() => {
    const element = scroller.current;
    if (element === null) return;
    // Left past the end by a list that shrank: the pager goes to the page that is now the last.
    const end = (pages.length - 1) * element.clientWidth;
    if (element.scrollLeft > end) element.scrollTo({ left: end });
  }, [pages]);

  useEffect(() => {
    // Without a ResizeObserver the pager is simply as tall as its tallest page.
    if (typeof ResizeObserver === 'undefined') return;
    const observer = new ResizeObserver((entries) => {
      setHeights((before) => {
        const next = before.slice();
        for (const entry of entries) {
          const at = pageElements.current.indexOf(entry.target);
          if (at >= 0) next[at] = entry.borderBoxSize[0].blockSize;
        }
        return next;
      });
    });
    for (const element of pageElements.current) {
      if (element !== null) observer.observe(element);
    }
    return () => observer.disconnect();
  }, [pages]);

  // A long press is for the page shown, wherever on the media it began.
  const press = useLongPress<HTMLDivElement>(
    onMore === undefined
      ? undefined
      : () => {
          const pressed = pages[shown];
          if (pressed !== undefined) onMore(targetOf(pressed));
        }
  );

  const onScroll = (event: ReactUIEvent<HTMLDivElement>) => {
    const element = event.currentTarget;
    if (element.clientWidth === 0) return;
    const at = Math.min(Math.round(element.scrollLeft / element.clientWidth), count - 1);
    setPage(at);
    // Still for this long after its last scroll event: the pager is at rest, also after a long fling.
    window.clearTimeout(settleTimer.current);
    settleTimer.current = window.setTimeout(() => setSettled(at), SETTLE_AFTER);
  };

  useEffect(() => () => window.clearTimeout(settleTimer.current), []);

  if (!showing) return null;

  const current = pages[shown];
  const height = heights[Math.min(settled, count - 1)];

  return (
    <div
      {...press}
      className="relative select-none [-webkit-touch-callout:none]"
      // The WebView's own menu for a long press on an image or a video: the sheet of the app is what opens.
      onContextMenu={(event) => event.preventDefault()}
    >
      <div
        ref={scroller}
        onScroll={onScroll}
        style={height === undefined ? undefined : { height }}
        className="flex snap-x snap-mandatory scroll-smooth items-start overflow-x-auto overflow-y-hidden transition-[height] duration-250 ease-out [scrollbar-width:none] motion-reduce:scroll-auto motion-reduce:transition-none"
      >
        {/* One swipe is one page: a fling would else skip as many pages as it carries. */}
        {pages.map((page, index) => (
          <div
            key={page.key}
            ref={(element) => {
              pageElements.current[index] = element;
            }}
            className="w-full shrink-0 snap-start snap-always"
          >
            {page.kind === 'image' && (
              <Picture
                src={page.url}
                name={`${page.index + 1}번째 이미지`}
                onOpen={onOpenImage === undefined ? undefined : () => onOpenImage(page.index)}
              />
            )}
            {page.kind === 'video' && (
              <InlineVideoPlayer id={videoId(postKey, page.blockIndex)} video={page.block} />
            )}
            {page.kind === 'poster' && <Picture src={page.url} name="동영상 미리보기" />}
          </div>
        ))}
      </div>
      {count > 1 && (
        <span
          role="status"
          aria-label={`이미지 ${shown + 1} / ${count}`}
          className="pointer-events-none absolute top-2 left-2 rounded-full bg-black/60 px-2 py-1 text-xs font-medium text-white tabular-nums"
        >
          {shown + 1} / {count}
        </span>
      )}
      {onMore !== undefined && (
        <Button
          type="button"
          variant="ghost"
          size="icon"
          aria-label="더보기"
          aria-haspopup="dialog"
          onClick={() => onMore(targetOf(current))}
          className="absolute top-2 right-2 size-11 rounded-full bg-black/60 text-white hover:bg-black/80 hover:text-white dark:hover:bg-black/80"
        >
          <MoreHorizontal aria-hidden="true" className="size-5" />
        </Button>
      )}
    </div>
  );
}

interface PictureProps {
  src: string;
  /** What the picture shows, for a screen reader: the name of its button where it has one. */
  name: string;
  /** Opens the picture full screen. Left out: the picture is not a button. */
  onOpen?: () => void;
}

/**
 * A picture in a box of its own shape, which is what the page is measured
 * by: square until the size of the picture is known, then its ratio, from
 * 120px to 600px high. The picture is asked for lazily, so a long post does
 * not load every picture at once. One that fails keeps its place, and says
 * so there with a way to try again.
 */
function Picture({ src, name, onOpen }: PictureProps) {
  const [size, setSize] = useState<{ width: number; height: number } | null>(null);
  const [failed, setFailed] = useState(false);
  // Asking again mounts the picture anew: it is what loads it.
  const [attempt, setAttempt] = useState(0);

  const shape = {
    className: 'relative min-h-[120px] max-h-[600px] w-full bg-muted',
    style: { aspectRatio: size === null ? '1 / 1' : `${size.width} / ${size.height}` },
  };

  // A failed picture is no button, so that 다시 시도 is a button of its own: a button may not hold a button.
  if (failed) {
    return (
      <div {...shape}>
        <div
          role="alert"
          className="absolute inset-0 flex flex-col items-center justify-center gap-2 text-muted-foreground"
        >
          <ImageOff aria-hidden="true" className="size-8" />
          <p className="text-sm">이미지를 불러오지 못했습니다</p>
          <Button
            type="button"
            variant="outline"
            className="h-11"
            onClick={() => {
              setFailed(false);
              setSize(null);
              setAttempt((count) => count + 1);
            }}
          >
            다시 시도
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div {...shape}>
      {size === null && <Skeleton aria-hidden="true" className="absolute inset-0 rounded-none" />}
      <img
        key={attempt}
        src={src}
        // Where a tap opens the viewer, the button over the picture is what is named: the picture itself is not.
        alt={onOpen === undefined ? name : ''}
        loading="lazy"
        decoding="async"
        referrerPolicy="no-referrer"
        draggable={false}
        onLoad={(event) => {
          const { naturalWidth, naturalHeight } = event.currentTarget;
          if (naturalWidth > 0 && naturalHeight > 0) {
            setSize({ width: naturalWidth, height: naturalHeight });
          }
        }}
        onError={() => setFailed(true)}
        className="absolute inset-0 size-full object-cover"
      />
      {/* The tap is a layer of its own over the picture, holding nothing: a button may hold phrasing content only. */}
      {onOpen !== undefined && (
        <button
          type="button"
          aria-label={name}
          onClick={onOpen}
          className="absolute inset-0 block w-full outline-none focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:ring-inset"
        />
      )}
    </div>
  );
}
