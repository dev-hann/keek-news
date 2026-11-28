import { ImageOff } from 'lucide-react';
import { toast } from 'sonner';
import { blockedImagesNotifier, useBlockedImages } from '../provider/blocked_images_provider';
import { AppBar } from '../widgets/app_bar';
import { BlockedImageTile } from '../widgets/blocked_image_tile';
import { EmptyStateView } from '../widgets/empty_state_view';

interface BlockedImagesViewProps {
  onBack: () => void;
}

/** The images the user blocked, each with a way to let it show again. */
export function BlockedImagesView({ onBack }: BlockedImagesViewProps) {
  const images = useBlockedImages();

  const unblock = async (url: string) => {
    const result = await blockedImagesNotifier().unblock(url);
    if (result.ok) toast.success('차단을 해제했어요');
    else toast.error('차단 해제에 실패했어요');
  };

  return (
    <div className="min-h-dvh bg-background">
      <AppBar title="차단된 이미지" onBack={onBack} />
      <main className="flex flex-col py-2">
        {images.length === 0 ? (
          <EmptyStateView
            message="차단된 이미지가 없어요"
            hint="이미지를 열어 메뉴에서 차단할 수 있어요"
            icon={ImageOff}
          />
        ) : (
          images.map((image) => (
            <BlockedImageTile
              key={image.url}
              image={image}
              onUnblock={() => void unblock(image.url)}
            />
          ))
        )}
      </main>
    </div>
  );
}
