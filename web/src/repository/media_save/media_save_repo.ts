import type { MediaSaveResult } from '../../model/media_save_failure';
import type { MediaTarget } from '../../model/media_target';

export interface MediaSaveRepo {
  /** Downloads the image at `url` and saves it to the device gallery. */
  saveImage(url: string): Promise<MediaSaveResult>;

  /** Downloads the video at `url` and saves it to the device gallery. */
  saveVideo(url: string): Promise<MediaSaveResult>;

  /**
   * Shares `target` through the system share sheet: the downloaded file when
   * possible, the URL as text for external embeds or as a fallback when the
   * download fails.
   */
  share(target: MediaTarget): Promise<MediaSaveResult>;
}
