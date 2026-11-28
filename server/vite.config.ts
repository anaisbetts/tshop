import cloudflare from "@cloudflare/oxlint-config/vite-plus";
import { defineConfig } from "vite-plus";
import { voidPlugin } from "void";

const DEV_HOST = "0.0.0.0";
const DEV_PORT = 8787;
const WRANGLER_PERSIST_DIR = ".wrangler/state";

export default defineConfig({
  fmt: {
    ignorePatterns: [
      "dist/**",
      ".void/**",
      ".wrangler/**",
      ".cloudflare/**",
      ".seed-cache/**",
      ".void-wrangler.jsonc",
      "bun.lock",
    ],
    printWidth: 80,
    semi: true,
    singleQuote: false,
    sortImports: {
      newlinesBetween: false,
    },
    trailingComma: "all",
  },
  lint: {
    extends: [cloudflare],
    env: cloudflare.env,
    ignorePatterns: [
      ...(cloudflare.ignorePatterns ?? []),
      "**/dist/**",
      "**/.void/**",
      "**/.wrangler/**",
      "**/.cloudflare/**",
      "**/.seed-cache/**",
    ],
    options: {
      typeAware: true,
      typeCheck: true,
    },
    overrides: [
      {
        files: ["scripts/**/*.ts"],
        rules: {
          "no-console": "off",
        },
      },
      {
        files: ["test/**/*.ts"],
        rules: {
          "quality/no-chained-type-assertions": "off",
          "typescript/no-unsafe-type-assertion": "off",
        },
      },
    ],
  },
  plugins: [
    voidPlugin({
      persistTo: WRANGLER_PERSIST_DIR,
    }),
  ],
  server: {
    allowedHosts: true,
    cors: false,
    host: DEV_HOST,
    port: DEV_PORT,
  },
  test: {
    include: ["test/**/*.test.ts"],
  },
});
