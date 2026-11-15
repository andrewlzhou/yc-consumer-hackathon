import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "edge-runtime",
    server: { deps: { inline: ["convex-test", "@convex-dev/rate-limiter"] } },
    // HTTP routes fail closed without APP_API_KEY; tests opt in to open routes and test the closed path explicitly.
    env: { APP_ALLOW_UNAUTHENTICATED: "1" },
  },
});
