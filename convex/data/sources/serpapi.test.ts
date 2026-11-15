import { convexTest } from "convex-test";
import { afterEach, describe, expect, test, vi } from "vitest";
import { internal } from "../../_generated/api";
import type { Id } from "../../_generated/dataModel";
import schema from "../../schema";
import { SEED_NOW } from "../../seed/generate";
import { modules } from "../../test.setup";
import { parseInsightDate } from "./serpapi";

// Hand-written from the documented responses (serpapi.com/google-shopping-api, /google-product-api).
const SHOPPING = {
  shopping_results: [
    { title: "Case for AirPods Pro 3", product_id: "999", source: "Best Buy", extracted_price: 19.99 },
    { title: "Apple AirPods Pro 3 Wireless Earbuds", product_id: "4242", source: "Walmart", extracted_price: 179.99, extracted_old_price: 249, product_link: "https://example.com/w", multiple_sources: true },
    { title: "Apple AirPods Pro 3 - Refurbished", product_id: "555", source: "Target", extracted_price: 129.99 },
  ],
};
const PRODUCT = {
  product_results: {
    title: "Apple AirPods Pro 3",
    brand: "Apple",
    stores: [
      { name: "Walmart", title: "Apple AirPods Pro 3", link: "https://example.com/w", extracted_price: 179.99, extracted_original_price: 249 },
      { name: "Walmart - SuperSeller", title: "Apple AirPods Pro 3", extracted_price: 150 },
      { name: "Amazon.com", title: "Apple AirPods Pro 3 Wireless Earbuds", extracted_price: 189.99 },
      { name: "Best Buy", title: "Apple - AirPods Pro 3 Wireless Earbuds", extracted_price: 199.99 },
    ],
    about_the_product: { features: [{ title: "Battery Life", value: "8 h" }] },
    price_insights: {
      price_history: true,
      currency: "USD",
      stores: [
        { name: "Amazon.com", prices: [{ date: "Oct 1, 2026", price: 229.0 }, { date: "Nov 10, 2026", price: 189.99 }] },
        { name: "Walmart - SuperSeller", prices: [{ date: "Nov 1, 2026", price: 150 }] },
      ],
    },
  },
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

function stubSerpApi() {
  const calls: string[] = [];
  vi.stubGlobal("fetch", vi.fn(async (url: URL) => {
    const engine = new URL(url).searchParams.get("engine")!;
    calls.push(engine);
    return new Response(JSON.stringify(engine === "google_shopping" ? SHOPPING : PRODUCT), { status: 200 });
  }));
  return calls;
}

test("insight dates become 17:00 UTC on that day", () => {
  expect(parseInsightDate("May 30, 2026")).toBe(Date.UTC(2026, 4, 30, 17));
  expect(parseInsightDate("not a date")).toBeNull();
});

test("without a key the refresh does nothing", async () => {
  const { t, airpods } = await seeded();
  expect(await t.action(internal.data.sources.serpapi.refreshCurrentPrices, { productId: airpods })).toEqual({ status: "no_key", recorded: 0 });
});

describe("refresh with a key", () => {
  test("finds the Google product once, records first-party offers and Google's price history", async () => {
    const { t, airpods } = await seeded();
    process.env.SERPAPI_API_KEY = "test-key";
    const calls = stubSerpApi();
    vi.useFakeTimers({ now: SEED_NOW + 60 * 60 * 1000, toFake: ["Date"] });
    const r = await t.action(internal.data.sources.serpapi.refreshCurrentPrices, { productId: airpods });
    vi.useRealTimers();
    expect(calls).toEqual(["google_shopping", "google_product"]);
    if (r.status !== "ok") throw new Error(r.status);
    expect(r.googleProductId).toBe("4242");
    expect(r.offers.map((o) => [o.retailerSlug, o.price, o.originalPrice])).toEqual([
      ["walmart", 179.99, 249],
      ["amazon", 189.99, undefined],
      ["bestbuy", 199.99, undefined],
    ]);
    expect(r.recorded).toBe(3);
    expect(r.historyPoints).toBe(2);
    const amazon = await t.query(internal.data.prices.getPriceHistory, { productId: airpods, retailerSlug: "amazon", from: SEED_NOW - 60 * 86400000, to: SEED_NOW + 86400000 });
    expect(amazon.points.map((p) => [p.price, p.provider])).toEqual([
      [229, "serpapi-google-price-history"],
      [189.99, "serpapi-google-price-history"],
      [189.99, "serpapi-google-product"],
    ]);
    const product = await t.query(internal.data.catalog.getProduct, { productId: airpods });
    expect(product!.identifiers?.googleProductId).toBe("4242");
  });

  test("a second refresh skips the search and writes no duplicate history", async () => {
    const { t, airpods } = await seeded();
    process.env.SERPAPI_API_KEY = "test-key";
    const calls = stubSerpApi();
    await t.action(internal.data.sources.serpapi.refreshCurrentPrices, { productId: airpods });
    const again = await t.action(internal.data.sources.serpapi.refreshCurrentPrices, { productId: airpods });
    expect(calls).toEqual(["google_shopping", "google_product", "google_product"]);
    if (again.status !== "ok") throw new Error(again.status);
    expect(again.historyPoints).toBe(0);
  });
});
