import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

declare const process: { env: Record<string, string | undefined> };

// Release links come from the repository the site is built for, so the source
// never names an account. Vercel and GitHub Actions each say which repository
// they are building; LINEFEED_REPOSITORY_URL overrides both.
const env = process.env;
const githubRepository =
  env.VERCEL_GIT_PROVIDER === "github" && env.VERCEL_GIT_REPO_OWNER && env.VERCEL_GIT_REPO_SLUG
    ? `${env.VERCEL_GIT_REPO_OWNER}/${env.VERCEL_GIT_REPO_SLUG}`
    : env.GITHUB_REPOSITORY;
const repository =
  env.LINEFEED_REPOSITORY_URL ?? (githubRepository ? `https://github.com/${githubRepository}` : "");

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
