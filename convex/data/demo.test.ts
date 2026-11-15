import { convexTest } from "convex-test";
import { afterEach, expect, test, vi } from "vitest";
import { internal } from "../_generated/api";
import type { Id } from "../_generated/dataModel";
import schema from "../schema";
import { SEED_NOW } from "../seed/generate";
import { modules } from "../test.setup";
import xm5 from "./sources/fixtures/serpapi-product-xm5.json";

afterEach(() => {
  vi.unstubAllGlobals();
  vi.unstubAllEnvs();
  vi.useRealTimers();
});

// The real Google product response for the XM5 (fetched 2026-11-15) drives the demo ingest end to end.
test("ingesting a demo product replaces its seeded history with real Google price history", async () => {
  const t = convexTest(schema, modules);
  const { products } = await t.action(internal.seed.run.all, {});
  const productId = products["sony-xm5"] as Id<"products">;
  vi.stubEnv("SERPAPI_API_KEY", "test-key");
  vi.stubEnv("OPENAI_API_KEY", "");
  const calls: string[] = [];
  vi.stubGlobal("fetch", vi.fn(async (url: URL) => {
    calls.push(new URL(url).searchParams.get("engine")!);
    return new Response(JSON.stringify(xm5), { status: 200 });
  }));
  vi.useFakeTimers({ now: SEED_NOW, toFake: ["Date"] });

  const r = await t.action(internal.data.demo.ingest, { key: "sony-xm5", wayback: false });
  expect(calls).toEqual(["google_product"]);
  expect(r.productId).toBe(productId);
  expect(r.deletedSeedPoints).toBeGreaterThan(100);
  if (r.serpapi.status !== "ok") throw new Error(r.serpapi.status);
  expect(r.serpapi.offers.map((o) => [o.retailerSlug, o.price, o.originalPrice])).toEqual([["bestbuy", 198, 398], ["target", 399.99, undefined]]);

  const stats = await t.query(internal.data.prices.getPriceStats, { productId, now: SEED_NOW, retailerSlug: "bestbuy", originalPrice: 398, currentPrice: 198 });
  expect(stats.isSampleData).toBe(false);
  expect(stats.overall.sources).not.toHaveProperty("seed");
  expect(stats.overall.prices).toMatchObject({ min: 198, max: 398 });
  expect(stats.overall.current).toMatchObject({ atOrBelowLow: true });
  expect(stats.wasPrice!.shareChargedAtOrAbove).toBeLessThan(0.15);

  const reseed = await t.action(internal.seed.run.all, {});
  expect(reseed.products["sony-xm5"]).toBe(productId);
  const after = await t.query(internal.data.prices.getPriceStats, { productId, now: SEED_NOW });
  expect(after.overall.sources).not.toHaveProperty("seed");
  expect(await t.query(internal.data.demo.demoProductIds, {})).toEqual([productId]);
});

test("operator cleanup removes only the named provider's rows at that instant", async () => {
  const t = convexTest(schema, modules);
  const { products } = await t.action(internal.seed.run.all, {});
  const productId = products["sony-xm6"] as Id<"products">;
  const at = SEED_NOW - 3600_000;
  for (const [retailer, price, provider] of [["bestbuy", 148, "serpapi-google-shopping"], ["target", 379.99, "serpapi-google-product"]] as const) {
    await t.mutation(internal.data.prices.recordObservation, { productId, retailer, price, observedAt: at, source: "api", provider });
  }
  const r = await t.mutation(internal.data.demo.removeObservationsAt, { productId, provider: "serpapi-google-shopping", observedAt: at });
  expect(r.deleted).toEqual([{ retailerSlug: "bestbuy", price: 148 }]);
  const left = await t.query(internal.data.prices.getPriceHistory, { productId, from: at - 1, to: at + 1 });
  expect(left.points.filter((p) => p.source === "api").map((p) => p.price)).toEqual([379.99]);
});
