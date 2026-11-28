import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

// The HTML samples are shared with the Flutter tests: test/fixtures/ of the repository.
// The path is resolved with node:path on purpose: Vite rewrites `new URL(path, import.meta.url)`
// into an address it serves, which is not a path on disk.
const here = dirname(fileURLToPath(import.meta.url));
const fixturesDirectory = resolve(here, '../../../test/fixtures');

export function readFixture(name: string): string {
  return readFileSync(resolve(fixturesDirectory, name), 'utf8');
}
