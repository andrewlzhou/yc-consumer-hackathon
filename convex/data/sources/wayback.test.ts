import { convexTest } from "convex-test";
import { afterEach, describe, expect, test, vi } from "vitest";
import { internal } from "../../_generated/api";
import type { Id } from "../../_generated/dataModel";
import schema from "../../schema";
import { modules } from "../../test.setup";
import real from "./fixtures/wayback-pages.json";
import { readProductPage } from "./pages";
import { parseCdx, spread, waybackTime } from "./wayback";

// Walmart and Target snippets are hand-written from the JSON those pages embed; Best Buy and Amazon are real excerpts.
const WALMART = '<script id="__NEXT_DATA__">{"priceInfo":{"currentPrice":{"price":75.0,"priceString":"$75.00"},"wasPrice":{"price":99.99,"priceString":"$99.99"}}}</script>';
const TARGET = '<script>window.__TGT_DATA__ = JSON.parse("{\\"price\\":{\\"current_retail\\":74.99,\\"reg_retail\\":99.99,\\"formatted_current_price\\":\\"$74.99\\"}}")</script>';

describe("product page parsing", () => {
  test("Best Buy: the New buying option, not open-box prices", () => {
    expect(readProductPage("bestbuy", real.bestbuy)).toMatchObject({ price: 249.99, pattern: "bestbuy.newBuyingOption", inStock: true });
  });

  test("Amazon page with no featured offer yields no price instead of a guess", () => {
    expect(readProductPage("amazon", real.amazonNoOffer)).toMatchObject({ price: null, originalPrice: null });
  });

  test("Walmart and Target embedded JSON, with the was-price", () => {
    expect(readProductPage("walmart", WALMART)).toMatchObject({ price: 75, originalPrice: 99.99 });
    expect(readProductPage("target", TARGET)).toMatchObject({ price: 74.99, originalPrice: 99.99 });
  });

  test("Amazon template text 'Currently unavailable' outside the availability block is not out of stock", () => {
    const page = '<h2 id="pqv-price">Price</h2><p>No featured offers available</p><div id="aod">Currently unavailable sellers</div>';
    expect(readProductPage("amazon", page)).toMatchObject({ price: null, inStock: null });
    expect(readProductPage("amazon", '<div id="availability"><span>Currently unavailable.</span></div>').inStock).toBe(false);
  });

  test("a captcha page is flagged as blocked", () => {
    expect(readProductPage("amazon", "<html><title>Robot Check</title>Enter the characters you see below</html>").blocked).toBe(true);
  });
});

describe("CDX handling", () => {
  test("one capture per day, oldest first, and timestamps in UTC", () => {
    const json = [
      ["urlkey", "timestamp", "original"],
      ["k", "20260315230000", "https://x/p"],
      ["k", "20260315010000", "https://x/p"],
      ["k", "20260101120000", "https://x/p"],
    ];
    expect(parseCdx(json).map((s) => s.timestamp)).toEqual(["20260101120000", "20260315230000"]);
    expect(waybackTime("20260315123045")).toBe(Date.UTC(2026, 2, 15, 12, 30, 45));
    expect(spread([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 4)).toEqual([1, 4, 7, 10]);
  });
});

afterEach(() => vi.unstubAllGlobals());

test("ingest writes each parsed snapshot once, as scrape/wayback with the snapshot as evidence", async () => {
  const t = convexTest(schema, modules);
  const { products } = await t.action(internal.seed.run.all, {});
  const productId = products["airpods-pro-3"] as Id<"products">;
  const cdx = [
    ["urlkey", "timestamp", "original"],
    ["k", "20251113023400", "https://www.bestbuy.com/product/x/JJGCQLYK5F"],
    ["k", "20260110120000", "https://www.bestbuy.com/product/x/JJGCQLYK5F"],
  ];
  vi.stubGlobal("fetch", vi.fn(async (url: string) => {
    if (url.includes("/cdx/")) return new Response(JSON.stringify(cdx));
    if (url.includes("20260110")) return new Response("<html>Robot Check captcha</html>");
    return new Response(real.bestbuy);
  }));
  const args = { productId, retailer: "bestbuy", url: "https://www.bestbuy.com/product/x/JJGCQLYK5F", pauseMs: 0 };
  const r = await t.action(internal.data.sources.wayback.ingest, args);
  expect(r).toMatchObject({ snapshots: 2, parsed: 1, blocked: 1, recorded: 1 });
  const again = await t.action(internal.data.sources.wayback.ingest, args);
  expect(again).toMatchObject({ skippedAlreadyIngested: 1, recorded: 0 });
  const h = await t.query(internal.data.prices.getPriceHistory, { productId, retailerSlug: "bestbuy", from: Date.UTC(2025, 10, 13), to: Date.UTC(2025, 10, 14) });
  const point = h.points.find((p) => p.provider === "wayback")!;
  expect(point).toMatchObject({ price: 249.99, source: "scrape", observedAt: Date.UTC(2025, 10, 13, 2, 34) });
});
