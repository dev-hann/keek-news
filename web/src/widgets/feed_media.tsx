import { Play } from 'lucide-react';
import type { VideoBlock } from '../model/content_block';
import type { LoadedPostDetail } from '../model/post_detail';
import { FeedImage } from './feed_image';

/** The images of a post, one under another, and a still picture for each of its videos. */
export function FeedMedia({ detail }: { detail: LoadedPostDetail }) {
  const posters = detail.contentBlocks.filter(
    (block): block is VideoBlock => block.type === 'video' && !!block.thumbnailUrl
  );
  if (detail.imageUrls.length === 0 && posters.length === 0) return null;

  return (
    <div className="flex flex-col gap-1">
      {detail.imageUrls.map((url, index) => (
        <FeedImage key={`${url}#${index}`} src={url} alt={`${index + 1}번째 이미지`} />
      ))}
      {posters.map((video) => (
        <div key={video.url} className="relative">
          <FeedImage src={video.thumbnailUrl ?? ''} alt="동영상 미리보기" />
          <span aria-hidden="true" className="absolute inset-0 flex items-center justify-center">
            <span className="flex size-14 items-center justify-center rounded-full bg-black/60 text-white">
              <Play className="size-7 translate-x-0.5" />
            </span>
          </span>
        </div>
      ))}
    </div>
  );
}
