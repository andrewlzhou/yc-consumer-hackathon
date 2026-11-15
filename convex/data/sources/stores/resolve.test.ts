import { convexTest } from "convex-test";
import { afterEach, expect, test, vi } from "vitest";
import { internal } from "../../../_generated/api";
import schema from "../../../schema";
import { modules } from "../../../test.setup";
import { waybackTime } from "../wayback";
import real from "./fixtures/store-pages.json";

afterEach(() => vi.unstubAllGlobals());

const PEG42 = "https://www.nike.com/t/pegasus-42-mens-road-running-shoes-S1bYkOza/II7210-100";
const ALIGN = "https://shop.lululemon.com/p/womens-leggings/Align-Pant-2/_/prod2020012";
const AE = "https://www.ae.com/us/en/p/men/jeans/baggy-loose-jeans/ae-baggy-jean/1114_7364_914";
const DAY = 86_400_000;

test("a Nike link matches the catalog product and stores the live page price", async () => {
  const t = convexTest(schema, modules);
  const productId = await t.mutation(internal.data.catalog.createProvisionalProduct, { title: "Nike Pegasus 42 Men's Road Running Shoes", brand: "Nike" });
  const fetchMock = vi.fn(async () => new Response(real.nikePeg42));
  vi.stubGlobal("fetch", fetchMock);
  const r = await t.action(internal.data.sources.stores.resolve.resolveUrl, { url: PEG42 + "?cp=123" });
  expect(r).toMatchObject({ productId, matched: "catalog", retailer: "nike", via: "live", currentPrice: 123.97, originalPrice: 145 });
  expect(fetchMock).toHaveBeenCalledTimes(1);
  const h = await t.query(internal.data.prices.getPriceHistory, { productId, from: Date.now() - DAY, to: Date.now() + DAY });
  expect(h.points).toMatchObject([{ retailerSlug: "nike", price: 123.97, originalPrice: 145, source: "scrape", provider: "store-page", url: PEG42 }]);
});

test("a store that blocks us falls back to its newest archived copy and creates a provisional product", async () => {
  const t = convexTest(schema, modules);
  const ts = "20260811075955";
  vi.stubGlobal("fetch", vi.fn(async (url: string) => {
    if (url.startsWith(ALIGN)) return new Response("Access Denied", { status: 403 });
    if (url.includes("/cdx/")) return new Response(JSON.stringify([["timestamp", "original"], [ts, ALIGN]]));
    if (url.includes(ts + "id_/")) return new Response(real.lululemonAlign);
    return new Response("", { status: 404 });
  }));
  const r = await t.action(internal.data.sources.stores.resolve.resolveUrl, { url: ALIGN });
  expect(r).toMatchObject({ matched: "created", retailer: "lululemon", via: "wayback", observedAt: waybackTime(ts), title: 'lululemon Align High-Rise Pant 25"' });
  // An archived price is history, not today's price.
  expect(r!.currentPrice).toBeUndefined();
  const h = await t.query(internal.data.prices.getPriceHistory, { productId: r!.productId!, from: waybackTime(ts) - DAY, to: waybackTime(ts) + DAY });
  expect(h.points).toMatchObject([{ retailerSlug: "lululemon", price: 98, provider: "wayback" }]);
});

test("unsupported stores return null without fetching anything", async () => {
  const t = convexTest(schema, modules);
  const fetchMock = vi.fn();
  vi.stubGlobal("fetch", fetchMock);
  expect(await t.action(internal.data.sources.stores.resolve.resolveUrl, { url: "https://www.zara.com/us/en/x-p123.html" })).toBeNull();
  expect(fetchMock).not.toHaveBeenCalled();
});

test("Wayback ingest reads brand-store snapshots, including copies saved with tracking query strings", async () => {
  const t = convexTest(schema, modules);
  const productId = await t.mutation(internal.data.catalog.createProvisionalProduct, { title: "AE Baggy Jean", brand: "American Eagle" });
  const cdxUrls: string[] = [];
  vi.stubGlobal("fetch", vi.fn(async (url: string) => {
    if (url.includes("/cdx/")) {
      cdxUrls.push(url);
      return new Response(JSON.stringify([["timestamp", "original"], ["20260211205804", AE + "?utm_medium=organic"], ["20260612053542", AE + "?menu=cat4840004"], ["20260716004800", AE + "?color=other"]]));
    }
    return new Response(real.aeBaggy);
  }));
  const r = await t.action(internal.data.sources.wayback.ingest, { productId, retailer: "ae", url: AE, prefix: true, pauseMs: 0 });
  expect(new URL(cdxUrls[0]).searchParams.get("matchType")).toBe("prefix");
  expect(r).toMatchObject({ snapshots: 2, parsed: 2, recorded: 2 });
  const h = await t.query(internal.data.prices.getPriceHistory, { productId, retailerSlug: "ae", from: Date.UTC(2026, 0, 1), to: Date.UTC(2026, 11, 1) });
  expect(h.points.map((p) => [p.price, p.originalPrice, p.provider])).toEqual([[24.99, 49.95, "wayback"], [24.99, 49.95, "wayback"]]);
});
