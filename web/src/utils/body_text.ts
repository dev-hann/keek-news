import type { LoadedPostDetail } from '../model/post_detail';

/**
 * Labels and bare-URL anchors inside a rich block stay visible. The raw
 * markup never reaches the screen.
 */
export function htmlBlockText(html: string): string {
  // Tags go before entities: decoded text such as "&lt;script&gt;" is words, not markup.
  return html
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<[^>]+>/g, ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&amp;', '&')
    .replace(/[ \t]+/g, ' ')
    .trim();
}

/** The words of a post, text blocks and rich blocks alike, one block per line. */
export function feedBodyText(detail: LoadedPostDetail): string | null {
  const texts: string[] = [];
  for (const block of detail.contentBlocks) {
    const text =
      block.type === 'text'
        ? block.text.trim()
        : block.type === 'html'
          ? htmlBlockText(block.html)
          : '';
    if (text.length > 0) texts.push(text);
  }
  return texts.length === 0 ? null : texts.join('\n');
}
