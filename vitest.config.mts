import { defineConfig } from "vitest/config";
import { cloudflareTest } from "@cloudflare/vitest-pool-workers";

export default defineConfig({
  plugins: [
    cloudflareTest({
      wrangler: { configPath: "./wrangler.toml" },
      miniflare: {
        bindings: {
          API_KEY: "test-api-key",
          PUSHOVER_TOKEN: "test-pushover-token",
          PUSHOVER_USER: "test-pushover-user",
        },
      },
    }),
  ],
});
