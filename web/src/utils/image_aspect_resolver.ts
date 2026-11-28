/** The width-to-height ratio of the image at `url`, as the browser loads it. */
export function resolveImageAspect(url: string): Promise<number> {
  return new Promise((resolve, reject) => {
    const image = new Image();
    // The app's images are loaded without a Referer: community CDNs refuse a foreign one.
    image.referrerPolicy = 'no-referrer';
    image.onload = () => {
      if (image.naturalHeight > 0) resolve(image.naturalWidth / image.naturalHeight);
      else reject(new Error(`The image at ${url} has no height`));
    };
    image.onerror = () => reject(new Error(`The image at ${url} did not load`));
    image.src = url;
  });
}
