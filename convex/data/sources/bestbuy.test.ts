import { convexTest } from "convex-test";
import { afterEach, expect, test, vi } from "vitest";
import { internal } from "../../_generated/api";
import schema from "../../schema";
import { modules } from "../../test.setup";
import { parseBestBuyProducts } from "./bestbuy";

// Fixtures are hand-written from the Best Buy Products API docs (https://bestbuyapis.github.io/api-documentation/):
// a collection wraps products in paging fields; a single SKU (/products/{sku}.json) returns the product itself.
const COLLECTION = {
  from: 1,
  to: 3,
  total: 3,
  currentPage: 1,
  totalPages: 1,
  queryTime: "0.005",
  totalTime: "0.035",
  partial: false,
  canonicalUrl: "/v1/products(search=airpods&search=pro)?show=sku,name,regularPrice,salePrice,onSale,url&format=json&apiKey=YourAPIKey",
  products: [
    { sku: 6447382, name: "Apple - AirPods Pro 3", regularPrice: 249.99, salePrice: 199.99, onSale: true, url: "https://api.bestbuy.com/click/5592e2b895800000/6447382/pdp" },
    { sku: 6447383, name: "Apple - AirPods Pro 3 Case", regularPrice: 29.99, salePrice: 29.99, onSale: false, url: "https://api.bestbuy.com/click/5592e2b895800000/6447383/pdp" },
    { sku: 6447384, name: "Apple - Item without a price" },
  ],
};

afterEach(() => {
  vi.unstubAllGlobals();
  delete process.env.BESTBUY_API_KEY;
});

test("parses a collection response and drops products without a sale price", () => {
  expect(parseBestBuyProducts(COLLECTION)).toEqual([
    { sku: 6447382, name: "Apple - AirPods Pro 3", regularPrice: 249.99, salePrice: 199.99, onSale: true, url: "https://api.bestbuy.com/click/5592e2b895800000/6447382/pdp" },
    { sku: 6447383, name: "Apple - AirPods Pro 3 Case", regularPrice: 29.99, salePrice: 29.99, onSale: false, url: "https://api.bestbuy.com/click/5592e2b895800000/6447383/pdp" },
  ]);
});

test("parses a single-sku response, filling regularPrice and onSale when show= omitted them", () => {
  expect(parseBestBuyProducts({ sku: 8880044, name: "Batman Begins (Blu-ray Disc)", salePrice: 9.99 })).toEqual([
    { sku: 8880044, name: "Batman Begins (Blu-ray Disc)", regularPrice: 9.99, salePrice: 9.99, onSale: false, url: undefined },
  ]);
  expect(parseBestBuyProducts({ error: { status: 403, message: "Forbidden" } })).toEqual([]);
  expect(parseBestBuyProducts(null)).toEqual([]);
});

test("without a key nothing is fetched, and without a query or sku nothing is asked", async () => {
  const t = convexTest(schema, modules);
  const fetchMock = vi.fn();
  vi.stubGlobal("fetch", fetchMock);
  expect((await t.action(internal.data.sources.bestbuy.getLivePrice, { query: "airpods" })).status).toBe("no_key");
  process.env.BESTBUY_API_KEY = "test-key";
  expect((await t.action(internal.data.sources.bestbuy.getLivePrice, { query: "  !! " })).status).toBe("no_query");
  expect(fetchMock).not.toHaveBeenCalled();
});

test("a keyword search requests only the needed fields and writes no observations", async () => {
  const t = convexTest(schema, modules);
  await t.action(internal.seed.run.all, {});
  const before = await t.run((ctx) => ctx.db.query("priceObservations").collect());
  process.env.BESTBUY_API_KEY = "test-key";
  const fetchMock = vi.fn(async () => new Response(JSON.stringify(COLLECTION), { status: 200 }));
  vi.stubGlobal("fetch", fetchMock);

  const r = await t.action(internal.data.sources.bestbuy.getLivePrice, { query: "Apple AirPods Pro 3" });
  expect(r.status).toBe("ok");
  expect(r.offers.map((o) => [o.sku, o.salePrice, o.onSale])).toEqual([[6447382, 199.99, true], [6447383, 29.99, false]]);

  const url = new URL(String((fetchMock.mock.calls[0] as unknown[])[0]));
  expect(decodeURIComponent(url.pathname)).toBe("/v1/products(search=Apple&search=AirPods&search=Pro&search=3)");
  expect(Object.fromEntries(url.searchParams)).toMatchObject({ show: "sku,name,regularPrice,salePrice,onSale,url", format: "json", apiKey: "test-key" });
  expect(await t.run((ctx) => ctx.db.query("priceObservations").collect())).toHaveLength(before.length);
});

test("a sku lookup uses the single-product endpoint; HTTP failures are reported", async () => {
  const t = convexTest(schema, modules);
  process.env.BESTBUY_API_KEY = "test-key";
  const fetchMock = vi.fn(async () => new Response(JSON.stringify(COLLECTION.products[0]), { status: 200 }));
  vi.stubGlobal("fetch", fetchMock);
  const ok = await t.action(internal.data.sources.bestbuy.getLivePrice, { sku: "6447382" });
  expect(ok.offers).toHaveLength(1);
  expect(new URL(String((fetchMock.mock.calls[0] as unknown[])[0])).pathname).toBe("/v1/products/6447382.json");

  vi.stubGlobal("fetch", vi.fn(async () => new Response("{}", { status: 403 })));
  expect(await t.action(internal.data.sources.bestbuy.getLivePrice, { sku: "6447382" })).toMatchObject({ status: "error", httpStatus: 403, offers: [] });
});
