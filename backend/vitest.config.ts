import swc from 'unplugin-swc';
import { defineConfig } from 'vitest/config';
import path from 'path';

export default defineConfig({
  test: {
    globals: true,
    root: './',
    include: ['**/*.spec.ts'],
    exclude: ['**/e2e/**', 'node_modules', 'dist'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov', 'html'],
      include: ['src/**/*.ts'],
      exclude: ['src/main.ts', 'src/**/*.module.ts', 'src/**/*.dto.ts', '**/*.spec.ts'],
    },
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'src'),
      '@test': path.resolve(__dirname, 'test'),
    },
  },
  plugins: [swc.vite()],
});
