import { useState } from 'react';
import { toast } from 'sonner';
import type { VideoBlock } from '../model/content_block';
import type { MediaSaveResult } from '../model/media_save_failure';
import type { MediaTarget } from '../model/media_target';
import type { VideoId } from '../model/video_id';
import { saveMediaUseCase, shareMediaUseCase } from '../service/service_locator';
import { copyText } from '../utils/clipboard';
import { blockedImagesNotifier } from './blocked_images_provider';

/** Copies the address of a picture or a video, not of the post it is in, and says whether it did. */
export async function copyMediaUrl(target: MediaTarget): Promise<void> {
  const copied = await copyText(target.url);
  if (copied) toast.success('링크를 복사했어요');
  else toast.error('링크를 복사하지 못했습니다');
}

/**
 * Hides the image at `url` from every post that shows it, and offers to take
 * that back: the row was tapped in a sheet, with no second look at the picture.
 */
export async function blockImage(url: string): Promise<void> {
  const result = await blockedImagesNotifier().block(url);
  if (!result.ok) {
    toast.error('차단하지 못했어요');
    return;
  }
  toast.success('이미지를 차단했어요', {
    action: { label: '취소', onClick: () => void unblockImage(url) },
  });
}

/** Shows the image at `url` again. */
export async function unblockImage(url: string): Promise<void> {
  const result = await blockedImagesNotifier().unblock(url);
  if (result.ok) toast.success('차단을 해제했어요');
  else toast.error('차단 해제에 실패했어요');
}

/**
 * Saves the picture or the video to the gallery. It says that it did, and
 * what to do about a permission the app lacks; how the sheet's row ends is
 * the sheet's to show, from the answer.
 */
export async function saveMedia(target: MediaTarget): Promise<MediaSaveResult> {
  const result = await saveMediaUseCase().call(target);
  if (result.ok) toast.success('저장했어요');
  else if (result.failure.type === 'permission') {
    toast.error('갤러리 접근 권한이 필요해요. 시스템 설정에서 허용해주세요');
  }
  return result;
}

/** Offers the picture, the video or its address to another app. */
export function shareMedia(target: MediaTarget): Promise<MediaSaveResult> {
  return shareMediaUseCase().call(target);
}

/**
 * The two overlays that the media of a post open on a page that lists posts:
 * the full-screen viewer and the media menu. The feed and the bookmarks list
 * each have one of each; a page spreads them where its cards are.
 */
export function useMediaOverlays(blockedUrls: Set<string>) {
  /** The images shown full screen, and the one that was opened. */
  const [viewer, setViewer] = useState<{ images: string[]; index: number } | null>(null);
  /** What the media menu acts on; null while it is closed. */
  const [target, setTarget] = useState<MediaTarget | null>(null);
  /** The video of a comment shown full screen, and the id its player answers to. */
  const [video, setVideo] = useState<{ id: VideoId; block: VideoBlock } | null>(null);

  return {
    /** Opens the viewer on the image at `index` of the post's images. */
    openImage: (images: string[], index: number) => setViewer({ images, index }),
    /** Opens a video of a comment full screen, playing at once. */
    openVideo: (id: VideoId, block: VideoBlock) => setVideo({ id, block }),
    openMore: setTarget,
    commentVideo: {
      id: video?.id ?? null,
      video: video?.block ?? null,
      open: video !== null,
      onClose: () => setVideo(null),
      onMore: setTarget,
    },
    viewer: {
      // Blocked images leave the viewer while it is open; once none is left, the viewer asks to close.
      images: viewer === null ? [] : viewer.images.filter((url) => !blockedUrls.has(url)),
      initialIndex: viewer?.index ?? 0,
      open: viewer !== null,
      onClose: () => setViewer(null),
      onMore: setTarget,
    },
    menu: {
      target,
      open: target !== null,
      onClose: () => setTarget(null),
      onCopy: (media: MediaTarget) => void copyMediaUrl(media),
      onBlock: (media: MediaTarget) => void blockImage(media.url),
      onSave: saveMedia,
      onShare: shareMedia,
    },
  };
}
