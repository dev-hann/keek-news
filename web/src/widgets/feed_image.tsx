import { ImageOff } from 'lucide-react';
import { Button } from '../components/ui/button';
import { Skeleton } from '../components/ui/skeleton';
import { useImageLoader } from '../utils/use_image_loader';

interface FeedImageProps {
  src: string;
  /** What the image shows, for a screen reader. */
  alt: string;
}

/** An image of a post: a placeholder while it loads, and a way to try again when it fails. */
export function FeedImage({ src, alt }: FeedImageProps) {
  const [state, retry] = useImageLoader(src);

  if (state === 'loaded') {
    return (
      <img
        src={src}
        alt={alt}
        loading="lazy"
        decoding="async"
        referrerPolicy="no-referrer"
        className="block max-h-[80vh] w-full bg-muted object-contain"
      />
    );
  }

  if (state === 'failed') {
    return (
      <div
        role="img"
        aria-label={`${alt} — 불러오지 못함`}
        className="flex aspect-[4/3] w-full flex-col items-center justify-center gap-2 bg-muted text-muted-foreground"
      >
        <ImageOff aria-hidden="true" className="size-8" />
        <p className="text-sm">이미지를 불러오지 못했습니다</p>
        <Button type="button" variant="outline" className="h-11" onClick={retry}>
          다시 시도
        </Button>
      </div>
    );
  }

  return <Skeleton aria-hidden="true" className="aspect-[4/3] w-full rounded-none" />;
}
