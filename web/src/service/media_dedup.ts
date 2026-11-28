/** Returns the filename portion of a media URL for deduplication.
 *
 * Two CDN mirrors of the same upload (e.g. `//cdn2.x/a/b/clip.mp4` and
 * `https://img.x/a/b/clip.mp4`) share the same filename, so keying on it
 * collapses them into one item.
 */
export function filenameKey(url: string): string {
  const noQuery = url.split('?')[0];
  const slash = noQuery.lastIndexOf('/');
  const file = slash >= 0 ? noQuery.substring(slash + 1) : noQuery;
  return file.toLowerCase();
}
