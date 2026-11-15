import { convexTest } from "convex-test";
import { beforeEach, describe, expect, test } from "vitest";
import { internal } from "../_generated/api";
import type { Id } from "../_generated/dataModel";
import schema from "../schema";
import { SEED_NOW } from "../seed/generate";
import { modules } from "../test.setup";
const DAY = 24 * 60 * 60 * 1000;

let t: ReturnType<typeof convexTest>;
let ids: Record<string, Id<"products">>;

beforeEach(async () => {
  t = convexTest(schema, modules);
  const seeded = await t.action(internal.seed.run.all, {});
  ids = seeded.products as Record<string, Id<"products">>;
});

const stats = (key: string, extra: Record<string, unknown> = {}) =>
  t.query(internal.data.prices.getPriceStats, { productId: ids[key], now: SEED_NOW, windowDays: 365, ...extra });
const promo = (key: string, extra: Record<string, unknown> = {}) =>
  t.query(internal.data.prices.findPromoPatterns, { productId: ids[key], now: SEED_NOW, ...extra });

describe("seeded scenarios", () => {
  test("reseeding is reproducible, keeps product ids, and leaves real scans alone", async () => {
    await t.mutation(internal.data.prices.recordObservation, { productId: ids["airpods-pro-3"], retailer: "target", price: 179.99, observedAt: SEED_NOW, source: "scan" });
    const again = await t.action(internal.seed.run.all, {});
    expect(again.observations).toBe(2728);
    expect(again.deletedSeedObservations).toBe(2728);
    expect(again.products).toEqual(ids);
    const h = await t.query(internal.data.prices.getPriceHistory, { productId: ids["airpods-pro-3"], from: SEED_NOW, to: SEED_NOW });
    expect(h.points.filter((p) => p.source === "scan")).toHaveLength(1);
  });

  test("BUY_NOW: AirPods Pro 3 at $179.99 matches the low and the $249 was-price is real", async () => {
    const s = await stats("airpods-pro-3", { currentPrice: 179.99, originalPrice: 249, retailerSlug: "walmart" });
    expect(s.isSampleData).toBe(true);
    expect(s.overall.prices).toMatchObject({ min: 179, median: 249 });
    expect(s.overall.current!.percentile).toBeLessThan(0.1);
    expect(s.wasPrice!.shareChargedAtOrAbove).toBeGreaterThan(0.6);
    const p = await promo("airpods-pro-3");
    const bf = p.upcoming.find((u) => u.name === "Black Friday 2026")!;
    expect(bf.daysAway).toBe(12);
    expect(Math.min(...bf.pastSales.map((s) => s.minPrice))).toBe(219);
  });

  test("WAIT: iPad 128GB is at full price and every recent big sale cut it", async () => {
    const recent = await stats("ipad-a16-128", { windowDays: 90, retailerSlug: "target" });
    expect(recent.overall.prices).toMatchObject({ median: 449, min: 399 });
    const p = await promo("ipad-a16-128");
    expect(p.recurrence.episodeCount).toBeGreaterThanOrEqual(10);
    expect(p.recurrence.seriesWithSales).toEqual(
      expect.arrayContaining(["black-friday", "presidents-day", "memorial-day", "summer-sales", "fall-sales"]),
    );
    const bf = p.upcoming.find((u) => u.name === "Black Friday 2026")!;
    expect(bf.pastSales.map((s) => s.minPrice).sort()).toEqual([274, 279, 279.99]);
    const walmart = await stats("ipad-a16-128", { windowDays: 7, retailerSlug: "walmart" });
    expect(walmart.overall.observationCount).toBe(0);
    expect(walmart.overall.outOfStockCount).toBeGreaterThan(0);
  });

  test("misleading discount: Ninja at Target was raised before its '25% off' sale", async () => {
    const p = await promo("ninja-af101", { retailerSlug: "target" });
    const ongoing = p.claimedDiscounts.find((c) => c.ongoing)!;
    expect(ongoing).toMatchObject({ minPrice: 74.99, claimedOriginalPrice: 99.99, claimedPct: 0.25, typicalBefore: 79.99, realPct: 0.063, preSaleHike: true });
    expect(p.episodes.filter((e) => e.ongoing)).toHaveLength(0);
    const s = await stats("ninja-af101", { currentPrice: 74.99, originalPrice: 99.99, retailerSlug: "target" });
    expect(s.wasPrice!.shareChargedAtOrAbove).toBeLessThan(0.1);
    expect(s.overall.prices!.min).toBe(59.99);
  });

  test("CONSIDER_ALTERNATIVE: Sony XM5 is a same-category comparable $149 under the Bose", async () => {
    const comps = await t.query(internal.data.catalog.findComparables, { productId: ids["bose-qcu-2"] });
    expect(comps.map((c) => c.familyKey).sort()).toEqual(["sony-wh-1000xm5", "sony-wh-1000xm6"]);
    const bose = await stats("bose-qcu-2", { windowDays: 7, retailerSlug: "bestbuy" });
    const sony = await stats("sony-xm5", { windowDays: 7, retailerSlug: "bestbuy" });
    expect(bose.overall.prices!.latest.price - sony.overall.prices!.latest.price).toBeCloseTo(149.01);
  });

  test("INVESTIGATE: Ember Mug has three observations", async () => {
    const s = await stats("ember-mug-2-10oz");
    expect(s.overall.observationCount).toBe(3);
    const p = await promo("ember-mug-2-10oz");
    expect(p.episodes).toHaveLength(0);
  });

  test("every seeded product has a digest that labels it as sample data", async () => {
    for (const id of Object.values(ids)) {
      const d = await t.query(internal.data.digests.getDigest, { productId: id });
      expect(d!.isSampleData).toBe(true);
      expect(d!.text.startsWith("SAMPLE DATA")).toBe(true);
    }
  });
});

describe("catalog matching", () => {
  const top = async (title: string) => (await t.query(internal.data.catalog.matchProduct, { title }))[0];

  test("storage variants are told apart", async () => {
    const m = await t.query(internal.data.catalog.matchProduct, { title: "Apple 11-inch iPad A16 Wi-Fi 256 GB - Silver" });
    expect(m[0].product.variant).toEqual({ storage: "256GB" });
    expect(m.find((c) => c.product.variant?.storage === "128GB")!.sizeConflict).toBe(true);
  });

  test("OCR-mangled titles still match", async () => {
    expect((await top("Ninja AFl0l Air Fryer w1th 4-Qt Cerarnic Basket")).product.familyKey).toBe("ninja-af101");
    expect((await top("Apple AirPods Pr0 3")).product.familyKey).toBe("apple-airpods-pro-3");
  });

  test("an unknown product has no strong match", async () => {
    const m = await t.query(internal.data.catalog.matchProduct, { title: "Stanley Quencher H2.0 FlowState Tumbler 40 oz" });
    expect(m.every((c) => c.score < 0.3)).toBe(true);
  });
});

describe("recordObservation", () => {
  const record = (args: Record<string, unknown>) =>
    t.mutation(internal.data.prices.recordObservation, { productId: ids["airpods-pro-3"], source: "scan", observedAt: SEED_NOW, ...args } as never);

  test("normalizes the retailer and drops a was-price below the price", async () => {
    const r = await record({ retailer: "Walmart.com", price: 189.994, originalPrice: 150 });
    expect(r).toMatchObject({ status: "recorded", retailerSlug: "walmart" });
    const h = await t.query(internal.data.prices.getPriceHistory, { productId: ids["airpods-pro-3"], retailerSlug: "walmart", from: SEED_NOW, to: SEED_NOW });
    const scan = h.points.find((p) => p.source === "scan")!;
    expect(scan.price).toBe(189.99);
    expect(scan.originalPrice).toBeUndefined();
  });

  test("rejects zero and far-off prices, stores out of stock without a price", async () => {
    expect((await record({ retailer: "target", price: 0 })).status).toBe("rejected");
    expect((await record({ retailer: "target", price: 9.99 })).status).toBe("rejected");
    expect((await record({ retailer: "target", inStock: false })).status).toBe("recorded");
    const s = await stats("airpods-pro-3", { windowDays: 1, retailerSlug: "target" });
    expect(s.overall.outOfStockCount).toBe(1);
  });

  test("skips a repeat of the same scan within six hours", async () => {
    await record({ retailer: "target", price: 179.99 });
    const again = await record({ retailer: "target", price: 179.99, observedAt: SEED_NOW + 60_000 });
    expect(again.status).toBe("duplicate");
  });
});

test("history reads are bounded and the calendar finds Black Friday", async () => {
  const h = await t.query(internal.data.prices.getPriceHistory, {
    productId: ids["airpods-pro-3"], from: SEED_NOW - 400 * DAY, to: SEED_NOW, limit: 50,
  });
  expect(h.points).toHaveLength(50);
  expect(h.truncated).toBe(true);
  expect(h.points[49].observedAt).toBeGreaterThan(h.points[0].observedAt);
  const cal = await t.query(internal.data.calendar.getSaleCalendar, { from: SEED_NOW, to: SEED_NOW + 20 * DAY, retailerSlug: "target" });
  expect(cal.map((e) => e.name)).toEqual(expect.arrayContaining(["Black Friday 2026", "Cyber Monday 2026"]));
  expect(cal.some((e) => e.retailerSlug === "walmart")).toBe(false);
});

test("recordBatch writes provider history once per day and drops bad points", async () => {
  const productId = ids["ember-mug-2-10oz"];
  const points = [
    { price: 99.95, inStock: true, observedAt: SEED_NOW - 3 * DAY },
    { price: 0, inStock: true, observedAt: SEED_NOW - 2 * DAY },
    { inStock: false, observedAt: SEED_NOW - DAY },
  ];
  const args = { productId, retailer: "amazon", source: "api" as const, provider: "keepa", points };
  expect(await t.mutation(internal.data.prices.recordBatch, args)).toEqual({ recorded: 2, skipped: 1 });
  expect(await t.mutation(internal.data.prices.recordBatch, args)).toEqual({ recorded: 0, skipped: 3 });
  const s = await t.query(internal.data.prices.getPriceStats, { productId, now: SEED_NOW, windowDays: 30, retailerSlug: "amazon" });
  expect(s.overall).toMatchObject({ observationCount: 1, outOfStockCount: 1, sources: { api: 2 } });
});
