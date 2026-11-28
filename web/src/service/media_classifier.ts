export type MediaType = 'image' | 'video' | 'audio' | 'youtube' | 'link' | 'unknown';

const imageExts = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.svg'];
const videoExts = ['.mp4', '.webm', '.avi', '.mov', '.mkv'];
const audioExts = ['.mp3', '.wav', '.ogg'];

const loadableImageExts = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'];

const downloadPhpUrlPattern = /download\.php\?url=(https?:\/\/[^&]+)/;
const youtubeIdPatterns = [
  /(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})/,
  /youtube\.com\/embed\/([a-zA-Z0-9_-]{11})/,
];

export function classify(url: string): MediaType {
  if (url === '') return 'unknown';

  const unwrapped = unwrapDownloadPhp(url) ?? url;
  const lower = unwrapped.toLowerCase();

  if (extractYoutubeId(unwrapped) !== null) return 'youtube';

  for (const ext of videoExts) {
    if (lower.endsWith(ext)) return 'video';
  }
  for (const ext of imageExts) {
    if (lower.endsWith(ext)) return 'image';
  }
  for (const ext of audioExts) {
    if (lower.endsWith(ext)) return 'audio';
  }

  if (lower.includes('thumb.php') || lower.includes('image_view')) return 'image';

  if (unwrapped.startsWith('http')) return 'link';

  return 'unknown';
}

export function unwrapDownloadPhp(url: string): string | null {
  return url.match(downloadPhpUrlPattern)?.[1] ?? null;
}

export function extractYoutubeId(url: string): string | null {
  for (const pattern of youtubeIdPatterns) {
    const match = pattern.exec(url);
    if (match !== null) return match[1];
  }
  return null;
}

export function isMedia(url: string): boolean {
  const t = classify(url);
  return t === 'image' || t === 'video' || t === 'audio' || t === 'youtube';
}

export function isLoadableImage(url: string): boolean {
  if (url === '') return false;

  if (url.includes('url_enc=')) return false;

  const lower = url.toLowerCase();
  const queryIdx = lower.indexOf('?');
  const path = queryIdx >= 0 ? lower.substring(0, queryIdx) : lower;

  if (lower.includes('thumb.php?url=')) return true;

  for (const ext of loadableImageExts) {
    if (path.endsWith(ext)) return true;
  }
  return false;
}
