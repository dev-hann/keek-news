import type { ContentBlock } from './content_block';

export interface Comment {
  id: number;
  author: string;
  content: string;
  date: Date;
  recommendCount: number;
  isBest: boolean;
  mediaBlocks: ContentBlock[];
  replies: Comment[];
}

/** The images a comment carries, in order. */
export function commentImageUrls(comment: Comment): string[] {
  return comment.mediaBlocks.flatMap((block) => (block.type === 'image' ? [block.url] : []));
}
