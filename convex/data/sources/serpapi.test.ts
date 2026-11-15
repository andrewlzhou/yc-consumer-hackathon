import { convexTest } from "convex-test";
import { afterEach, expect, test, vi } from "vitest";
import { internal } from "../../_generated/api";
import type { Id } from "../../_generated/dataModel";
import schema from "../../schema";
import { SEED_NOW } from "../../seed/generate";
import { modules } from "../../test.setup";

// Shaped like SerpApi's documented google_shopping response (shopping_results with extracted prices).
const FIXTURE = {
  shopping_results: [
    { title: "Apple AirPods Pro 3 Wireless Earbuds", source: "Walmart", extracted_price: 179.99, extracted_old_price: 249, product_link: "https://example.com/w" },
    { title: "Apple AirPods Pro 3 - Refurbished", source: "Target", extracted_price: 129.99 },
    { title: "Case for AirPods Pro 3", source: "Best Buy", extracted_price: 19.99 },
    { title: "Apple AirPods Pro 3", source: "Walmart - SuperSeller", extracted_price: 150 },
    { title: "Apple AirPods Pro (3rd generation) AirPods Pro 3", source: "Best Buy", extracted_price: 199.99, product_link: "https://example.com/b" },
    { title: "Apple AirPods Pro 3", source: "Walmart", extracted_price: 189 },
  ],
};

afterEach(() => {
  vi.unstubAllGlobals();
  delete process.env.SERPAPI_API_KEY;
});

async function seeded() {
  const t = convexTest(schema, modules);
  const { products } = await t.action(internal.seed.run.all, {});
  return { t, airpods: products["airpods-pro-3"] as Id<"products"> };
}

test("without a key the refresh does nothing", async () => {
  const { t, airpods } = await seeded();
  expect(await t.action(internal.data.sources.serpapi.refreshCurrentPrices, { productId: airpods })).toEqual({ status: "no_key", recorded: 0 });
});

test("keeps one first-party offer per retailer and records it as api data", async () => {
  const { t, airpods } = await seeded();
  process.env.SERPAPI_API_KEY = "test-key";
  vi.useFakeTimers({ now: SEED_NOW + 60 * 60 * 1000, toFake: ["Date"] });
  vi.stubGlobal("fetch", vi.fn(async () => new Response(JSON.stringify(FIXTURE), { status: 200 })));
  const r = await t.action(internal.data.sources.serpapi.refreshCurrentPrices, { productId: airpods });
  vi.useRealTimers();
  expect(r.status).toBe("ok");
  if (r.status !== "ok") return;
  expect(r.offers.map((o) => [o.retailerSlug, o.price, o.originalPrice])).toEqual([
    ["walmart", 179.99, 249],
    ["bestbuy", 199.99, undefined],
  ]);
  expect(r.recorded).toBe(2);
  const h = await t.query(internal.data.prices.getPriceHistory, { productId: airpods, from: SEED_NOW, to: SEED_NOW + 2 * 60 * 60 * 1000 });
  expect(h.points.filter((p) => p.source === "api")).toHaveLength(2);
});
