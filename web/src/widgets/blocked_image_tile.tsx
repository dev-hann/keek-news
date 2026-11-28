import { ImageOff, RotateCcw } from 'lucide-react';
import { cn } from 'cn';
import { Button } from '../components/ui/button';
import type { BlockedImage } from '../model/blocked_image';
import { formatTimeAgo } from '../utils/time_ago';
import { useImageLoader } from '../utils/use_image_loader';
import { ActionButton } from './action_button';

interface BlockedImageTileProps {
  image: BlockedImage;
  /** Shows the picture over the whole screen. Without it the picture is only shown. */
  onOpenPreview?: () => void;
  onUnblock: () => void;
}

/** The 72px box the picture is shown in, whatever became of loading it. */
const THUMBNAIL =
  'flex size-18 shrink-0 items-center justify-center overflow-hidden rounded-lg bg-muted';

/**
 * One image the user blocked: the picture itself (nothing filters it here),
 * when it was blocked and its address, and a way to unblock it.
 */
export function BlockedImageTile({ image, onOpenPreview, onUnblock }: BlockedImageTileProps) {
  const [state] = useImageLoader(image.url);
  // The address next to the picture says what it is; one that failed is never a broken picture.
  const picture =
    state === 'loaded' ? (
      <img
        src={image.url}
        alt=""
        loading="lazy"
        decoding="async"
        referrerPolicy="no-referrer"
        className="size-full object-cover"
      />
    ) : state === 'failed' ? (
      <ImageOff aria-hidden="true" className="size-8 text-muted-foreground" />
    ) : null;

  return (
    <div className="flex items-center gap-3 px-4 py-2">
      {onOpenPreview ? (
        // The button's own 1px border would frame the picture with the page: the box is all picture.
        <Button
          type="button"
          variant="ghost"
          size="icon"
          aria-label="전체화면으로 보기"
          onClick={onOpenPreview}
          className={cn(THUMBNAIL, 'border-0')}
        >
          {picture}
        </Button>
      ) : (
        <span className={THUMBNAIL}>{picture}</span>
      )}
      <div className="min-w-0 flex-1">
        <p className="text-sm text-muted-foreground">{formatTimeAgo(image.blockedAt)}</p>
        <p className="truncate text-sm text-muted-foreground">{image.url}</p>
      </div>
      <ActionButton icon={RotateCcw} label="차단 해제" onClick={onUnblock} />
    </div>
  );
}
