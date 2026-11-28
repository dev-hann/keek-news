import { cleanup } from '@testing-library/react';
import { afterEach } from 'vitest';

// What a test rendered does not stay on the screen of the next one.
afterEach(() => {
  cleanup();
});
