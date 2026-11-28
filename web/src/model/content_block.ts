export type ContentBlock = TextBlock | ImageBlock | VideoBlock | HtmlBlock;

export interface TextBlock {
  type: 'text';
  text: string;
}

export interface ImageBlock {
  type: 'image';
  url: string;
  thumbnailUrl?: string;
}

export interface VideoBlock {
  type: 'video';
  url: string;
  thumbnailUrl?: string;
  width?: number;
  height?: number;
  isGifConversion?: boolean;
}

export interface HtmlBlock {
  type: 'html';
  html: string;
}
