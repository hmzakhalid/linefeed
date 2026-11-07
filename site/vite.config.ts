import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

declare const process: { env: Record<string, string | undefined> };

// Release links come from the repository the site is built for, so the source
// never names an account. GitHub Actions provides GITHUB_REPOSITORY.
const repository =
  process.env.LINEFEED_REPOSITORY_URL ??
  (process.env.GITHUB_REPOSITORY ? `https://github.com/${process.env.GITHUB_REPOSITORY}` : "");

export default defineConfig({
  base: "./",
  plugins: [react()],
  define: {
    __LINEFEED_REPOSITORY__: JSON.stringify(repository),
  },
  build: {
    outDir: "dist",
    emptyOutDir: true,
    sourcemap: false,
  },
});
