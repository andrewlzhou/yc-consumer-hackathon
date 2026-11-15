import { convexTest } from "convex-test";
import { afterEach, describe, expect, test, vi } from "vitest";
import { internal } from "../../_generated/api";
import type { Id } from "../../_generated/dataModel";
import schema from "../../schema";
import { SEED_NOW } from "../../seed/generate";
import { modules } from "../../test.setup";
import type { Doc } from "../../_generated/dataModel";
import { SEED_PRODUCTS } from "../../seed/catalog";
import { buildSearchText } from "../text";
import shopping from "./fixtures/serpapi-shopping.json";
import { dailySteps, parseInsightDate, parseShoppingResults } from "./serpapi";

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
  vi.unstubAllEnvs();
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

test("price changes expand to one point per day until the next change or the newest date", () => {
  const day = (d: number) => Date.UTC(2026, 9, d, 17);
  const steps = dailySteps([
    { retailerSlug: "target", price: 100, observedAt: day(1) },
    { retailerSlug: "target", price: 80, observedAt: day(4) },
    { retailerSlug: "bestbuy", price: 90, observedAt: day(5) },
  ]);
  expect(steps.filter((s) => s.retailerSlug === "target").map((s) => s.price)).toEqual([100, 100, 100, 80, 80]);
  expect(steps.filter((s) => s.retailerSlug === "bestbuy").map((s) => s.observedAt)).toEqual([day(5)]);
});

// Real Google Shopping results: the wrong model (XM5 for XM6), earbuds for headphones, and kits are not offers.
test("real shopping results keep only the exact product", () => {
  const product = (key: string) => {
    const p = SEED_PRODUCTS.find((x) => x.key === key)!;
    return { ...p, searchText: buildSearchText([p.title, p.brand, p.model, ...p.aliases]), isSample: false, provisional: false } as unknown as Doc<"products">;
  };
  const offers = (json: unknown, key: string) => parseShoppingResults(json, product(key)).map((o) => [o.retailerSlug, o.price, o.originalPrice]);
  expect(offers(shopping.xm5, "sony-xm6")).toEqual([]);
  expect(offers(shopping.xm6, "sony-xm6")).toEqual([["bestbuy", 378, 458], ["target", 391.49, 450]]);
  expect(offers(shopping.xm5, "sony-xm5")).toEqual([["bestbuy", 198, 398]]);
  expect(offers(shopping.bose, "bose-qcu-2")).toEqual([["bestbuy", 339.99, 449]]);
  const cheap = { shopping_results: [{ title: "Sony WH-1000XM6 Wireless Noise Canceling Headphones", source: "Best Buy", extracted_price: 148, extracted_old_price: 248 }] };
  expect(offers(cheap, "sony-xm6")).toEqual([]);
});

test("insight dates become 17:00 UTC on that day", () => {
  expect(parseInsightDate("May 30, 2026")).toBe(Date.UTC(2026, 4, 30, 17));
  expect(parseInsightDate("not a date")).toBeNull();
});

test("without a key the refresh does nothing", async () => {
  vi.stubEnv("SERPAPI_API_KEY", "");
  const { t, airpods } = await seeded();
  expect(await t.action(internal.data.sources.serpapi.refreshCurrentPrices, { productId: airpods })).toEqual({ status: "no_key", recorded: 0 });
});

describe("refresh with a key", () => {
  test("finds the Google product once, records first-party offers and Google's price history", async () => {
    const { t, airpods } = await seeded();
    vi.stubEnv("SERPAPI_API_KEY", "test-key");
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
    // Oct 1 -> Nov 9 at 229 (40 days), then Nov 10 at 189.99: Google's change points expanded to daily steps.
    expect(r.historyPoints).toBe(41);
    const amazon = await t.query(internal.data.prices.getPriceHistory, { productId: airpods, retailerSlug: "amazon", from: SEED_NOW - 60 * 86400000, to: SEED_NOW + 86400000 });
    const history = amazon.points.filter((p) => p.provider === "serpapi-google-price-history");
    expect(history.filter((p) => p.price === 229)).toHaveLength(40);
    expect(history.at(-1)).toMatchObject({ price: 189.99, observedAt: Date.UTC(2026, 10, 10, 17) });
    expect(amazon.points.at(-1)).toMatchObject({ price: 189.99, provider: "serpapi-google-product" });
    const product = await t.query(internal.data.catalog.getProduct, { productId: airpods });
    expect(product!.identifiers?.googleProductId).toBe("4242");
  });

  test("a second refresh skips the search and writes no duplicate history", async () => {
    const { t, airpods } = await seeded();
    vi.stubEnv("SERPAPI_API_KEY", "test-key");
    const calls = stubSerpApi();
    await t.action(internal.data.sources.serpapi.refreshCurrentPrices, { productId: airpods });
    const again = await t.action(internal.data.sources.serpapi.refreshCurrentPrices, { productId: airpods });
    expect(calls).toEqual(["google_shopping", "google_product", "google_product"]);
    if (again.status !== "ok") throw new Error(again.status);
    expect(again.historyPoints).toBe(0);
  });
});
