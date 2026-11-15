import { convexTest } from "convex-test";
import { afterEach, expect, test, vi } from "vitest";
import { internal } from "../_generated/api";
import schema from "../schema";
import { modules } from "../test.setup";

afterEach(() => vi.unstubAllEnvs());

// Without an embedding key both sides are text-only, so the scores must agree; this guards the harness itself.
test("match eval runs on the seeded catalog and scores text-only fallback identically", async () => {
  vi.stubEnv("OPENAI_API_KEY", "");
  const t = convexTest(schema, modules);
  await t.action(internal.seed.run.all, {});
  const r = await t.action(internal.data.matchEval.run, {});
  expect(r.summary.all.text).toBe(r.summary.all.hybrid);
  const missed = r.misses.map((m) => m.title);
  for (const title of ["Sony WH-1000XM4 Wireless Noise Canceling Headphones", "Bose QuietComfort Ultra Earbuds 2nd Gen", "Apple iPad Air 11-inch M3 128GB", "Sony WH-1000XM5 Replacement Ear Pads"]) {
    expect(missed).not.toContain(title);
  }
  expect(r.summary["near-duplicate"].text).toMatch(/^\d+\/7$/);
});
