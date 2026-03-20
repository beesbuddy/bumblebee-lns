import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';

const outDir = process.env.BUILD_OUT_DIR || 'dist';
const devPort = Number(process.env.BUMBLEBEE_FRONTEND_DEV_PORT || 5173);

export default defineConfig({
  plugins: [vue()],
  server: {
    host: true,
    port: devPort,
    strictPort: true,
    hmr: {
      clientPort: devPort
    }
  },
  build: {
    outDir
  }
});
