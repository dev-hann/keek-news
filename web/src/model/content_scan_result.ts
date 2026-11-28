import type { ContentBlock } from './content_block';

export interface ContentScanResult {
  blocks: ContentBlock[];
  imageUrls: string[];
}
