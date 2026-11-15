import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import rateLimiterTest from "@convex-dev/rate-limiter/test";
import { internal } from "../_generated/api";
import type { Id } from "../_generated/dataModel";
import schema from "../schema";
import { SEED_NOW } from "../seed/generate";
import { modules } from "../test.setup";
import { forecastPrice, type Promo } from "./insights";
import { hybridViable, mentionsBrand, type HybridCandidate } from "./identify";
import { normalizeUrl } from "./urls";

let t: ReturnType<typeof convexTest>;
let ids: Record<string, Id<"products">>;

beforeEach(async () => {
  vi.stubEnv("AGENT_PROVIDER", "fake");
  vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout"] });
  t = convexTest(schema, modules);
  rateLimiterTest.register(t);
  ids = (await t.action(internal.seed.run.all, {})).products as Record<string, Id<"products">>;
});
afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllEnvs();
});

const scan = async (extract: Record<string, unknown>) => (await t.action(internal.agent.analyze.analyzeScan, { now: SEED_NOW, ...extract })).response;
const fullReport = async (extract: Record<string, unknown>) => {
  const r = await scan(extract);
  await t.finishAllScheduledFunctions(vi.runAllTimers);
  const report = await t.query(internal.agent.store.report, { productId: r.productId as Id<"products">, now: SEED_NOW });
  expect(report!.analysis!.tier).toBe("full");
  return report!;
};

describe("report sections", () => {
  test("a better price before Black Friday comes as a range with confidence, and the chart is ready to draw", async () => {
    const report = await fullReport({ title: "Apple iPad 11-inch A16 Wi-Fi 128GB", retailer: "Target", currentPrice: 449 });
    const f = report.analysis!.insights!.forecast;
    expect(f).toMatchObject({ outlook: "better_price_likely", basedOn: "past_event_editions" });
    expect(f.low!).toBeLessThan(449 * 0.95);
    expect(f.high!).toBeGreaterThanOrEqual(f.low!);
    expect(f.confidence).toBeGreaterThan(0.4);
    expect(f.confidence).toBeLessThanOrEqual(0.8);
    expect(report.analysis!.insights!.retailerPatterns.length).toBeGreaterThan(1);
    expect(report.chart.isSampleData).toBe(true);
    expect(report.chart.series.length).toBeGreaterThan(1);
    expect(report.chart.events.some((e: { name: string }) => /black friday/i.test(e.name))).toBe(true);
    const points = report.chart.series.flatMap((s: { points: unknown[] }) => s.points).length;
    expect(points).toBeLessThan(report.chart.sources.seed);
  });

  test("a price raised before the sale shows up in discount authenticity", async () => {
    const report = await fullReport({ title: "Ninja AF101 Air Fryer 4 Quart", retailer: "Target", currentPrice: 74.99, originalPrice: 99.99 });
    const d = report.analysis!.insights!.discountAuthenticity;
    expect(d.preSaleHikes.length).toBeGreaterThan(0);
    expect(d.claimedWasPrice).toBe(99.99);
  });

  test("competitors are compared on specs and price", async () => {
    const report = await fullReport({ title: "Bose QuietComfort Ultra Headphones (2nd Gen)", retailer: "Best Buy", currentPrice: 399, originalPrice: 449 });
    const sony = report.analysis!.insights!.competitorComparison.find((c: { title: string }) => /sony/i.test(c.title));
    expect(sony!.savingsVsCurrent!).toBeGreaterThan(0);
    expect(sony!.specs.some((s: { same: boolean }) => s.same)).toBe(true);
    expect(report.analysis!.verdict).toBe("CONSIDER_ALTERNATIVE");
  });

  test("a competitor's price is the cheapest retailer's current price, not the last one observed", async () => {
    const report = await fullReport({ title: "Bose QuietComfort Ultra Headphones (2nd Gen)", retailer: "Best Buy", currentPrice: 399 });
    for (const c of report.analysis!.insights!.competitorComparison) {
      const stats = await t.query(internal.data.prices.getPriceStats, { productId: c.productId as Id<"products">, now: SEED_NOW, windowDays: 90 });
      const fresh = stats.perRetailer.flatMap((r) => (r.prices && SEED_NOW - r.prices.latest.observedAt <= 14 * 86_400_000 ? [r.prices.latest.price] : []));
      expect(c.latestPrice).toBe(Math.min(...fresh));
    }
  });

  test("a newer live analysis wins over an older full one", async () => {
    await fullReport({ title: "Apple AirPods Pro 3", retailer: "Walmart", currentPrice: 179.99 });
    const later = await t.action(internal.agent.analyze.analyzeScan, { now: SEED_NOW + 13 * 3_600_000, title: "Apple AirPods Pro 3", retailer: "Walmart", currentPrice: 199.99 });
    const report = await t.query(internal.agent.store.report, { productId: ids["airpods-pro-3"], now: SEED_NOW });
    expect(report!.analysis!.analysisId).toBe(later.analysisId);
    expect(report!.pending).toBe(true);
  });
});

describe("product links", () => {
  const link = "https://www.walmart.com/ip/Apple-AirPods-Pro-3/123456?athbdg=L1600";
  test("tracking parameters share a cache entry without merging product variants", () => {
    expect(normalizeUrl(link)).toBe(normalizeUrl("https://walmart.com/ip/Apple-AirPods-Pro-3/123456"));
    expect(normalizeUrl("https://shop.example/product?sku=128")).not.toBe(normalizeUrl("https://shop.example/product?sku=256"));
  });

  test("a failed resolver can retry after its cooldown", async () => {
    const key = normalizeUrl(link)!;
    await t.mutation(internal.agent.urls.settle, { url: key, error: "temporary", now: SEED_NOW });
    expect(await t.query(internal.agent.urls.lookup, { url: link, now: SEED_NOW })).toMatchObject({ status: "failed" });
    expect(await t.query(internal.agent.urls.lookup, { url: link, now: SEED_NOW + 300_000 })).toBeNull();
    expect(await t.mutation(internal.agent.urls.claim, { url: key, now: SEED_NOW + 300_000 })).toBe(true);
  });

  test("a link resolves in the background, then identifies the product on its own", async () => {
    const first = await scan({ title: "Apple AirPods Pro 3", retailer: "Walmart", currentPrice: 179.99, url: link });
    expect(first.productId).toBe(ids["airpods-pro-3"]);
    await t.finishAllScheduledFunctions(vi.runAllTimers);
    const again = await scan({ url: "https://walmart.com/ip/Apple-AirPods-Pro-3/123456" });
    expect(again.productId).toBe(ids["airpods-pro-3"]);
  });

  test("a link alone returns a quick pending card, and an unresolvable one says so", async () => {
    const first = await scan({ url: "https://www.target.com/p/mystery-thing/-/A-999" });
    expect(first).toMatchObject({ verdict: "INVESTIGATE", reportStatus: "pending" });
    await t.finishAllScheduledFunctions(vi.runAllTimers);
    const again = await scan({ url: "https://www.target.com/p/mystery-thing/-/A-999" });
    expect(again).toMatchObject({ verdict: "INVESTIGATE", reportStatus: "none" });
  });

  test("POST /analyze accepts a link without a title and rejects a non-link", async () => {
    const post = (body: unknown) => t.fetch("/analyze", { method: "POST", body: JSON.stringify(body) });
    expect((await post({ deviceId: "d1", url: "javascript:alert(1)" })).status).toBe(400);
    expect((await post({ deviceId: "d1", url: link })).status).toBe(200);
  });
});

describe("forecast", () => {
  const promo = (over: Partial<Promo>): Promo => ({ episodes: [], claimedDiscounts: [], upcoming: [], recurrence: { episodeCount: 0, medianGapDays: null }, ...over });
  test("no history means no forecast", () => {
    expect(forecastPrice(promo({}), 100, "2026-11-15")).toMatchObject({ outlook: "unknown", low: null, confidence: 0 });
  });
  test("the forecast range comes from the event its date names", () => {
    const event = (name: string, price: number, endsAt: string) => ({ name, startsAt: endsAt, endsAt, daysAway: 12, dateConfidence: "confirmed", pastSales: [{ retailerSlug: "target", startAt: "2025-11-28", minPrice: price }] });
    const f = forecastPrice(promo({ upcoming: [event("Black Friday", 80, "2026-11-27"), event("Cyber Monday", 60, "2026-11-30")] }), 100, "2026-11-15");
    expect(f).toMatchObject({ eventName: "Cyber Monday", low: 60, high: 60, byDate: "2026-11-30" });
  });
  test("a regular sale cycle forecasts the next sale date and its range", () => {
    const ep = (startAt: string, minPrice: number) => ({ retailerSlug: "target", startAt, endAt: startAt, minPrice, depthPercent: 20, ongoing: false, preSaleHike: false, preSaleHikePercent: null, events: [] });
    const f = forecastPrice(promo({ episodes: [ep("2026-08-01", 80), ep("2026-09-01", 82), ep("2026-10-01", 79)], recurrence: { episodeCount: 3, medianGapDays: 30 } }), 100, "2026-11-15");
    expect(f).toMatchObject({ basedOn: "sale_cycle", low: 79, high: 82, byDate: "2026-11-30", outlook: "better_price_possible" });
    expect(f.confidence).toBeLessThanOrEqual(0.55);
  });
});

describe("hybrid suggestions", () => {
  const cand = (brand: string, score: number, vectorScore: number) => ({ product: { brand }, score, vectorScore, sizeConflict: false, matchedTokens: [] }) as unknown as HybridCandidate;
  test("OCR spellings still name the brand", () => {
    expect(mentionsBrand("B0SE QuietC0mfort Ultra", "Bose")).toBe(true);
    expect(mentionsBrand("S0NY WH-1OOOXM5", "Sony")).toBe(true);
    expect(mentionsBrand("Sony WH-1000XM4", "Bose")).toBe(false);
  });
  test("vector-only look-alikes need a high score and the same brand", () => {
    expect(hybridViable([cand("Bose", 0.25, 0.521)], "Sony WH-1000XM4 Headphones")).toEqual([]);
    expect(hybridViable([cand("Bose", 0.1, 0.7)], "Sony WH-1000XM4 Headphones")).toEqual([]);
    expect(hybridViable([cand("Sony", 0.39, 0.644)], "S0NY WH-1OOOXM5 Headphones")).toHaveLength(1);
  });
});
