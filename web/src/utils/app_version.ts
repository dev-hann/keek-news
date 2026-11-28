const VERSION = /^v?(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$/i;

/** The version a release tag names, as text: `4.1.0` for `v4.1.0`. Null for a tag that is not a version. */
export function versionOfTag(tag: string): string | null {
  const match = VERSION.exec(tag.trim());
  if (match === null) return null;
  return `${Number(match[1])}.${Number(match[2])}.${Number(match[3])}`;
}

/** Whether `remote` names a version newer than `current`. False when either is not a version. */
export function isNewerVersion(remote: string, current: string): boolean {
  const a = VERSION.exec(remote.trim());
  const b = VERSION.exec(current.trim());
  if (a === null || b === null) return false;
  for (let part = 1; part <= 3; part++) {
    const difference = Number(a[part]) - Number(b[part]);
    if (difference !== 0) return difference > 0;
  }
  return false;
}
