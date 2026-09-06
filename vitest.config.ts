import { defineConfig } from 'vitest/config';
import { fileURLToPath } from 'node:url';

export default defineConfig({
  resolve: {
    alias: {
      'three-bvh-csg': fileURLToPath(new URL('./node_modules/three-bvh-csg/src/index.js', import.meta.url)),
    },
  },
  test: {
    setupFiles: ['./src/testSetup.ts'],
  },
});
