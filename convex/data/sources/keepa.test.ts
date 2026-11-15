import { convexTest } from "convex-test";
import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { internal } from "../../_generated/api";
import type { Id } from "../../_generated/dataModel";
import schema from "../../schema";
import { modules } from "../../test.setup";
import { keepaTimeToUnixMs, parseKeepaProduct, parseKeepaSearch, type KeepaProduct } from "./keepa";

// Fixtures are hand-written from Keepa's docs (https://keepa.com/api-docs/product-object.html and product-search.html):
// csv is a flat [keepaTime, value, ...] array (buy box adds shipping), prices are cents, -1 means no offer.
const NOW = Date.UTC(2026, 10, 15, 20, 0);
const kt = (iso: string) => Date.parse(iso) / 60_000 - 21_564_000;
const dollars = (p: { price?: number }) => p.price;

const AMAZON_CSV = [
  kt("2026-11-01T00:00Z"), 19999,
  kt("2026-11-08T09:00Z"), -1,
  kt("2026-11-10T12:00Z"), 14999,
  kt("2026-11-12T18:00Z"), 12999,
];
const BUY_BOX_CSV = [
  kt("2026-11-01T00:00Z"), 24999, 0,
  kt("2026-11-12T00:00Z"), 22999, 500,
  kt("2026-11-13T00:00Z"), -1, -1,
];
const amazonProduct: KeepaProduct = {
  asin: "B0TESTAMZ1",
  title: "Example Wireless Earbuds",
  upcList: ["195949000001"],
  eanList: ["0195949000001"],
  csv: [AMAZON_CSV, null, null],
};
const buyBoxOnlyProduct: KeepaProduct = { asin: "B0TESTBOX1", title: "Marketplace Only Item", csv: [[kt("2026-11-01T00:00Z"), -1], null, ...Array(16).fill(null), BUY_BOX_CSV] };

const SEARCH_FIXTURE = {
  timestamp: 1753592460000,
  tokensLeft: 268,
  tokensConsumed: 10,
  products: ["A", "B", "C", "D", "E", "F"].map((x) => ({ asin: `B0SEARCH0${x}`, title: `Result ${x}` })),
};

const keepaResponse = (product: KeepaProduct, tokensLeft = 250) => new Response(JSON.stringify({ tokensLeft, products: [product] }), { status: 200 });

beforeEach(() => {
  vi.useFakeTimers({ now: NOW, toFake: ["Date"] });
});

afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllGlobals();
  delete process.env.KEEPA_API_KEY;
});

async function seeded() {
  const t = convexTest(schema, modules);
  const { products } = await t.action(internal.seed.run.all, {});
  return { t, airpods: products["airpods-pro-3"] as Id<"products"> };
}

test("keepa time converts to unix ms using the documented offset", () => {
  expect(keepaTimeToUnixMs(0)).toBe(Date.UTC(2011, 0, 1));
  expect(new Date(keepaTimeToUnixMs(7_663_880)).toISOString()).toBe("2025-07-28T03:20:00.000Z");
  expect(keepaTimeToUnixMs(kt("2026-11-15T20:00Z"))).toBe(NOW);
});

test("expands change points into one sample per UTC day at 17:00, in dollars, with -1 as out of stock", () => {
  const parsed = parseKeepaProduct(amazonProduct, { now: NOW, days: 10 });
  expect(parsed).toMatchObject({ asin: "B0TESTAMZ1", title: "Example Wireless Earbuds", upc: "195949000001", ean: "0195949000001", series: "amazon" });
  expect(parsed.points).toHaveLength(10);
  expect(parsed.points.every((p) => new Date(p.observedAt).getUTCHours() === 17)).toBe(true);
  expect(parsed.points.map(dollars)).toEqual([199.99, 199.99, undefined, undefined, 149.99, 149.99, 149.99, 129.99, 129.99, 129.99]);
  expect(parsed.points.map((p) => p.inStock)).toEqual([true, true, false, false, true, true, true, true, true, true]);
  expect(parsed.points[2]).not.toHaveProperty("price");
});

test("skips days before the first known change and days that have not reached 17:00 yet", () => {
  expect(parseKeepaProduct(amazonProduct, { now: NOW, days: 400 }).points).toHaveLength(15);
  const morning = parseKeepaProduct(amazonProduct, { now: Date.UTC(2026, 10, 15, 9, 0), days: 10 });
  expect(morning.points).toHaveLength(9);
  expect(morning.points.at(-1)?.observedAt).toBe(Date.UTC(2026, 10, 14, 17, 0));
});

test("falls back to the buy box landing price when Amazon never had an offer in the window", () => {
  const parsed = parseKeepaProduct(buyBoxOnlyProduct, { now: NOW, days: 5 });
  expect(parsed.series).toBe("buybox");
  expect(parsed.points.map(dollars)).toEqual([249.99, 234.99, undefined, undefined, undefined]);
});

test("reports no series when neither Amazon nor the buy box has an offer", () => {
  expect(parseKeepaProduct({ asin: "B0NOHISTORY", title: "x", csv: [null, null] }, { now: NOW, days: 30 })).toMatchObject({ series: "none", points: [] });
  expect(parseKeepaProduct({ asin: "B0NOCSV", title: "x" }, { now: NOW, days: 30 }).points).toEqual([]);
});

test("parses a product search response to the top five asin and title pairs", () => {
  const results = parseKeepaSearch(SEARCH_FIXTURE);
  expect(results).toHaveLength(5);
  expect(results[0]).toEqual({ asin: "B0SEARCH0A", title: "Result A" });
  expect(parseKeepaSearch({})).toEqual([]);
});

test("without a key nothing is fetched", async () => {
  const { t, airpods } = await seeded();
  const fetchMock = vi.fn();
  vi.stubGlobal("fetch", fetchMock);
  expect((await t.action(internal.data.sources.keepa.ingestHistory, { productId: airpods })).status).toBe("no_key");
  expect((await t.action(internal.data.sources.keepa.searchAsins, { term: "airpods" })).status).toBe("no_key");
  expect(fetchMock).not.toHaveBeenCalled();
});

test("a product without an ASIN is reported and Keepa is not called", async () => {
  const { t, airpods } = await seeded();
  process.env.KEEPA_API_KEY = "test-key";
  const fetchMock = vi.fn();
  vi.stubGlobal("fetch", fetchMock);
  expect((await t.action(internal.data.sources.keepa.ingestHistory, { productId: airpods })).status).toBe("no_asin");
  expect(fetchMock).not.toHaveBeenCalled();
});

async function amazonApiPoints(t: ReturnType<typeof convexTest>, productId: Id<"products">, provider: string) {
  const h = await t.query(internal.data.prices.getPriceHistory, { productId, retailerSlug: "amazon", from: NOW - 30 * 24 * 3600_000, to: NOW, limit: 3000 });
  return h.points.filter((p) => p.provider === provider);
}

test("ingests daily Amazon history through recordBatch and a rerun writes nothing new", async () => {
  const { t, airpods } = await seeded();
  await t.run((ctx) => ctx.db.patch(airpods, { identifiers: { asin: "B0TESTAMZ1" } }));
  process.env.KEEPA_API_KEY = "test-key";
  const fetchMock = vi.fn(async () => keepaResponse(amazonProduct, 249));
  vi.stubGlobal("fetch", fetchMock);

  const first = await t.action(internal.data.sources.keepa.ingestHistory, { productId: airpods, days: 10 });
  expect(first).toMatchObject({ status: "ok", recorded: 10, series: "amazon", tokensLeft: 249 });
  const requested = new URL(String((fetchMock.mock.calls[0] as unknown[])[0]));
  expect(Object.fromEntries(requested.searchParams)).toMatchObject({ key: "test-key", domain: "1", asin: "B0TESTAMZ1", history: "1", days: "10" });
  expect(requested.searchParams.has("offers")).toBe(false);
  expect(fetchMock).toHaveBeenCalledTimes(1);

  const stored = await amazonApiPoints(t, airpods, "keepa-amazon");
  expect(stored).toHaveLength(10);
  expect(stored.filter((p) => !p.inStock && p.price === undefined)).toHaveLength(2);
  expect(stored.every((p) => p.source === "api")).toBe(true);

  const second = await t.action(internal.data.sources.keepa.ingestHistory, { productId: airpods, days: 10 });
  expect(second).toMatchObject({ status: "ok", recorded: 0, series: "amazon" });
  expect(await amazonApiPoints(t, airpods, "keepa-amazon")).toHaveLength(10);
});

test("asks for the paid buy box data only when Amazon has no offer, and tags the provider", async () => {
  const { t, airpods } = await seeded();
  await t.run((ctx) => ctx.db.patch(airpods, { identifiers: { asin: "B0TESTBOX1" } }));
  process.env.KEEPA_API_KEY = "test-key";
  const withoutBuyBox: KeepaProduct = { asin: "B0TESTBOX1", title: "Marketplace Only Item", csv: [[kt("2026-11-01T00:00Z"), -1], null] };
  const fetchMock = vi.fn(async (input: unknown) => keepaResponse(new URL(String(input)).searchParams.has("offers") ? buyBoxOnlyProduct : withoutBuyBox));
  vi.stubGlobal("fetch", fetchMock);

  const r = await t.action(internal.data.sources.keepa.ingestHistory, { productId: airpods, days: 5 });
  expect(r).toMatchObject({ status: "ok", recorded: 5, series: "buybox" });
  expect(fetchMock).toHaveBeenCalledTimes(2);
  expect(new URL(String((fetchMock.mock.calls[1] as unknown[])[0])).searchParams.get("offers")).toBe("20");
  expect(await amazonApiPoints(t, airpods, "keepa-buybox")).toHaveLength(5);
  expect(await amazonApiPoints(t, airpods, "keepa-amazon")).toHaveLength(0);
});

test("surfaces rate limits and Keepa errors without writing", async () => {
  const { t, airpods } = await seeded();
  await t.run((ctx) => ctx.db.patch(airpods, { identifiers: { asin: "B0TESTAMZ1" } }));
  process.env.KEEPA_API_KEY = "test-key";
  vi.stubGlobal("fetch", vi.fn(async () => new Response("{}", { status: 429 })));
  expect(await t.action(internal.data.sources.keepa.ingestHistory, { productId: airpods })).toMatchObject({ status: "rate_limited", recorded: 0 });
  vi.stubGlobal("fetch", vi.fn(async () => new Response("{}", { status: 500 })));
  expect(await t.action(internal.data.sources.keepa.ingestHistory, { productId: airpods })).toMatchObject({ status: "error", httpStatus: 500, recorded: 0 });
});

test("searchAsins sends a product search and returns the top five", async () => {
  const { t } = await seeded();
  process.env.KEEPA_API_KEY = "test-key";
  const fetchMock = vi.fn(async () => new Response(JSON.stringify(SEARCH_FIXTURE), { status: 200 }));
  vi.stubGlobal("fetch", fetchMock);
  const r = await t.action(internal.data.sources.keepa.searchAsins, { term: "airpods pro 3" });
  expect(r).toMatchObject({ status: "ok", tokensLeft: 268 });
  expect(r.results).toHaveLength(5);
  const url = new URL(String((fetchMock.mock.calls[0] as unknown[])[0]));
  expect(url.pathname).toBe("/search");
  expect(Object.fromEntries(url.searchParams)).toMatchObject({ type: "product", domain: "1", term: "airpods pro 3" });
});
