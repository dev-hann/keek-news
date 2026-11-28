import { CircleAlert, LoaderCircle, Pause, Play } from 'lucide-react';
import {
  useEffect,
  useRef,
  useState,
  type ChangeEvent,
  type MouseEvent,
  type SyntheticEvent,
} from 'react';
import { cn } from 'cn';
import type { VideoBlock } from '../model/content_block';
import type { VideoId } from '../model/video_id';
import {
  feedVideoPlaybackNotifier,
  useActiveVideo,
} from '../provider/feed_video_playback_provider';
import { useImageLoader } from '../utils/use_image_loader';
import { ControlButton, VideoBottomBar } from './video_controls';

/** The controls go away this long after the video started to play, or was last shown them. */
const CONTROLS_HIDE_AFTER = 3000;
/** Under this share of it on screen, a playing video pauses. */
const PAUSE_BELOW = 0.4;
/** The shape a video holds until anything knows its own. */
const WIDE = '16 / 9';

/** What the video element last said about itself. The controls are drawn from it. */
interface Playback {
  playing: boolean;
  /** No frame to show yet, or the data ran out: the spinner shows. */
  buffering: boolean;
  /** A frame was drawn: from here the video covers its poster. */
  hasFrame: boolean;
  failed: boolean;
  time: number;
  duration: number;
  /** How far the video is loaded, in seconds. */
  buffered: number;
}

const loading = (): Playback => ({
  playing: false,
  buffering: true,
  hasFrame: false,
  failed: false,
  time: 0,
  duration: Number.NaN,
  buffered: 0,
});

function loadedThrough(video: HTMLVideoElement): number {
  const ranges = video.buffered;
  return ranges.length === 0 ? 0 : ranges.end(ranges.length - 1);
}

interface InlineVideoPlayerProps {
  /** Tells this video from every other of the feed: the one that may play is the one the playback notifier names. */
  id: VideoId;
  video: VideoBlock;
  /** Plays at once, without the 재생 step: for a viewer that was opened for this video. */
  autoStart?: boolean;
  /** The stage is as large as what holds it, not a shape of its own: for a viewer that is the screen. */
  fill?: boolean;
}

/**
 * A video of a post where the card shows it. Nothing of the video is asked
 * for until the reader taps; from there it plays muted and looped under
 * controls of its own, and only while the playback notifier names it.
 */
export function InlineVideoPlayer(props: InlineVideoPlayerProps) {
  // The same place that shows another video is a player nobody has tapped yet.
  return <VideoStage key={`${props.id} ${props.video.url}`} {...props} />;
}

function VideoStage({ id, video, autoStart = false, fill = false }: InlineVideoPlayerProps) {
  const active = useActiveVideo() === id;
  const rootRef = useRef<HTMLDivElement>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const controlsRef = useRef<HTMLDivElement>(null);
  const [tapped, setTapped] = useState(false);
  const started = tapped || autoStart;
  const [playback, setPlayback] = useState(loading);
  const [controlsHidden, setControlsHidden] = useState(false);
  /** Counts the 3-second waits the controls were given: each starts again where the last was. */
  const [waits, setWaits] = useState(0);
  const [muted, setMuted] = useState(true);
  const [fullscreen, setFullscreen] = useState(false);

  useEffect(() => {
    if (autoStart) feedVideoPlaybackNotifier().setActive(id);
  }, [autoStart, id]);

  useEffect(() => {
    const element = videoRef.current;
    // A video that is not the active one neither plays nor loads; one already playing is left alone.
    if (element === null || !active || !element.paused) return;
    void element.play().catch(() => undefined);
  }, [active, started, playback.failed]);

  useEffect(() => {
    const element = videoRef.current;
    if (!active && element !== null && !element.paused) element.pause();
  }, [active]);

  useEffect(() => {
    const root = rootRef.current;
    // A document without the observer (a test's) simply has no rule for it.
    if (root === null || typeof IntersectionObserver === 'undefined') return;
    const observer = new IntersectionObserver(
      ([entry]) => {
        const element = videoRef.current;
        if (entry.intersectionRatio < PAUSE_BELOW && element !== null && !element.paused) {
          element.pause();
        }
      },
      { threshold: PAUSE_BELOW }
    );
    observer.observe(root);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    // The system Back of the shell leaves full screen too: the document is asked, nothing is remembered.
    const follow = () => setFullscreen(document.fullscreenElement === rootRef.current);
    document.addEventListener('fullscreenchange', follow);
    return () => document.removeEventListener('fullscreenchange', follow);
  }, []);

  useEffect(() => {
    if (!playback.playing || controlsHidden) return;
    const timer = setTimeout(() => {
      // The keyboard's focus is never left under what cannot be seen.
      if (controlsRef.current?.matches(':has(:focus-visible)')) return;
      setControlsHidden(true);
    }, CONTROLS_HIDE_AFTER);
    return () => clearTimeout(timer);
  }, [playback.playing, controlsHidden, waits]);

  /** Starting the video makes it the one that may play: every other one gives way. */
  const claim = () => feedVideoPlaybackNotifier().setActive(id);

  const toggle = () => {
    const element = videoRef.current;
    if (element === null) return;
    if (element.paused) {
      claim();
      void element.play().catch(() => undefined);
    } else {
      element.pause();
    }
  };

  /** The 3 seconds that hide the controls start again. */
  const waitAgain = () => setWaits((count) => count + 1);
  const reveal = () => {
    setControlsHidden(false);
    waitAgain();
  };

  const onStageTap = (event: MouseEvent<HTMLDivElement>) => {
    // A control answers a click of its own; that is not a tap on the stage.
    if (controlsRef.current?.contains(event.target as Node)) return;
    if (!started) {
      claim();
      setTapped(true);
    } else if (playback.failed) {
      // A new load is a new video element: the old one gave up.
      claim();
      setPlayback(loading);
    } else if (controlsHidden) {
      reveal();
    } else {
      // As in Flutter: a tap on the stage shows or hides the controls, and never plays or pauses.
      setControlsHidden(true);
    }
  };

  const onPlay = () => setPlayback((state) => ({ ...state, playing: true }));

  const onPause = () => {
    setPlayback((state) => ({ ...state, playing: false, buffering: false }));
    // A paused video says how to go on.
    setControlsHidden(false);
  };

  const onPlaying = () => setPlayback((state) => ({ ...state, playing: true, buffering: false }));

  /** The first frame can be drawn, paused or playing: the poster gives way to it. */
  const onLoadedData = () => setPlayback((state) => ({ ...state, hasFrame: true }));

  const onStall = (event: SyntheticEvent<HTMLVideoElement>) => {
    // A paused video is not waiting for anything.
    if (event.currentTarget.paused) return;
    setPlayback((state) => ({ ...state, buffering: true }));
  };

  const onError = () => {
    // The poster comes back: there is no frame of this video to show.
    setPlayback((state) => ({
      ...state,
      failed: true,
      playing: false,
      buffering: false,
      hasFrame: false,
    }));
    setControlsHidden(false);
  };

  /** Reads where the browser moved: the position of the video, and how far it is loaded. */
  const onProgress = (event: SyntheticEvent<HTMLVideoElement>) => {
    const element = event.currentTarget;
    setPlayback((state) => ({
      ...state,
      time: element.currentTime,
      buffered: loadedThrough(element),
    }));
  };

  const onDurationChange = (event: SyntheticEvent<HTMLVideoElement>) => {
    // Read before the state is set: an event keeps its element only while it is being handled.
    const { duration } = event.currentTarget;
    setPlayback((state) => ({ ...state, duration }));
  };

  const onScrub = (event: ChangeEvent<HTMLInputElement>) => {
    const element = videoRef.current;
    if (element === null) return;
    const to = Number(event.target.value);
    element.currentTime = to;
    setPlayback((state) => ({ ...state, time: to }));
  };

  const onToggleMute = () => setMuted((value) => !value);

  const onToggleFullscreen = () => {
    const request = fullscreen ? document.exitFullscreen() : rootRef.current?.requestFullscreen();
    // A refusal leaves the video where it is: there is nothing to tell.
    if (request !== undefined) void request.catch(() => undefined);
  };

  const canFullscreen = typeof Element.prototype.requestFullscreen === 'function';
  const shown = started && !playback.failed;
  // The stage keeps the shape it reserved, whatever the video's own: a card does not move when a video starts.
  const shape = video.width && video.height ? `${video.width} / ${video.height}` : WIDE;

  return (
    <div
      ref={rootRef}
      onClick={onStageTap}
      style={fill ? undefined : { aspectRatio: shape }}
      className={cn(
        'relative overflow-hidden bg-black select-none [&:fullscreen]:fixed [&:fullscreen]:inset-0',
        fill && 'size-full'
      )}
    >
      {video.thumbnailUrl !== undefined && (
        <Poster src={video.thumbnailUrl} covered={playback.hasFrame} />
      )}
      {shown && (
        <video
          ref={videoRef}
          src={video.url}
          playsInline
          loop
          muted={muted}
          // The active video loads ahead; any other one stops where it is.
          preload={active ? 'auto' : 'none'}
          disablePictureInPicture
          disableRemotePlayback
          onPlay={onPlay}
          onPause={onPause}
          onPlaying={onPlaying}
          onWaiting={onStall}
          onStalled={onStall}
          onError={onError}
          onLoadedData={onLoadedData}
          onTimeUpdate={onProgress}
          onProgress={onProgress}
          onDurationChange={onDurationChange}
          className={cn(
            'absolute inset-0 size-full object-contain',
            !playback.hasFrame && 'opacity-0'
          )}
        />
      )}
      {shown && playback.buffering && <Buffering />}
      {/* The one control left when there is no other: it takes a tap anywhere on the stage. */}
      {(!started || playback.failed || controlsHidden) && (
        <button
          type="button"
          aria-label={!started ? '재생' : playback.failed ? '탭하여 재시도' : '컨트롤 표시'}
          className="absolute inset-0 flex items-center justify-center"
        >
          {!started && (
            <span className="flex size-16 items-center justify-center rounded-full bg-black/40 text-white">
              <Play aria-hidden="true" className="size-10 translate-x-0.5" />
            </span>
          )}
        </button>
      )}
      {shown && (
        <div
          ref={controlsRef}
          // A reader that reaches a hidden control without seeing it gets to see it too.
          onClickCapture={() => {
            if (controlsHidden) reveal();
          }}
          onBlur={(event) => {
            // Out of the controls: if the keyboard kept them up, their time runs again.
            if (!event.currentTarget.contains(event.relatedTarget as Node | null)) waitAgain();
          }}
          className={cn(
            'absolute inset-0 transition-opacity duration-250 ease-in-out motion-reduce:transition-none',
            controlsHidden ? 'opacity-0' : 'opacity-100'
          )}
        >
          {!playback.buffering && (
            <ControlButton
              label={playback.playing ? '일시정지' : '재생'}
              shown={!controlsHidden}
              onClick={toggle}
              // Above the bar, as in Flutter: on a stage as short as a card's, the bar's gradient reaches the middle of it.
              className="absolute inset-0 m-auto z-10 size-16 rounded-full bg-black/40 hover:bg-black/40"
            >
              {playback.playing ? (
                <Pause aria-hidden="true" className="size-10" />
              ) : (
                <Play aria-hidden="true" className="size-10 translate-x-0.5" />
              )}
            </ControlButton>
          )}
          {/* A clip the site made of a GIF has no sound and needs no way out of the card. */}
          {video.isGifConversion !== true && (
            <VideoBottomBar
              playing={playback.playing}
              time={playback.time}
              duration={playback.duration}
              buffered={playback.buffered}
              shown={!controlsHidden}
              muted={muted}
              fullscreen={fullscreen}
              canFullscreen={canFullscreen}
              onToggle={toggle}
              onScrub={onScrub}
              onToggleMute={onToggleMute}
              onToggleFullscreen={onToggleFullscreen}
            />
          )}
        </div>
      )}
      {playback.failed && (
        <div
          role="alert"
          className="pointer-events-none absolute inset-0 flex items-center justify-center text-white"
        >
          <p className="flex flex-col items-center gap-1 rounded-lg bg-black/60 px-4 py-3 text-center text-xs">
            <CircleAlert aria-hidden="true" className="size-8 text-white/70" />
            <span>동영상을 불러올 수 없습니다</span>
            <span className="text-white/70">탭하여 재시도</span>
          </p>
        </div>
      )}
    </div>
  );
}

/** The still of the video, asked for without a Referer like everything the communities serve. */
function Poster({ src, covered }: { src: string; covered: boolean }) {
  const [state] = useImageLoader(src);
  if (state !== 'loaded') return null;
  return (
    <img
      src={src}
      alt=""
      draggable={false}
      referrerPolicy="no-referrer"
      decoding="async"
      className={cn('absolute inset-0 size-full object-cover', covered && 'hidden')}
    />
  );
}

function Buffering() {
  return (
    <p
      role="status"
      className="pointer-events-none absolute inset-0 flex items-center justify-center text-white"
    >
      <LoaderCircle
        aria-hidden="true"
        className="size-10 animate-spin motion-reduce:animate-none"
      />
      <span className="sr-only">동영상 불러오는 중</span>
    </p>
  );
}
