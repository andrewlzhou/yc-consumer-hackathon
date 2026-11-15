import { convexTest } from "convex-test";
import { beforeEach, describe, expect, test } from "vitest";
import cases from "../../eval/cases.json";
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
  ids = (await t.action(internal.seed.run.all, {})).products as Record<string, Id<"products">>;
});

const byId = (id: string) => cases.cases.find((c) => c.id === id)!;

// The retrieval layer must find the right product for every eval case before the agent can judge it.
describe("eval cases: product identification", () => {
  for (const c of cases.cases) {
    test(c.id, async () => {
      const candidates = await t.query(internal.data.catalog.matchProduct, { title: c.extract.title! });
      const expected = c.expect.match as { familyKey: string; variant?: Record<string, string> } | null;
      if (expected === null) {
        expect(candidates.every((x) => x.score < 0.3)).toBe(true);
        return;
      }
      expect(candidates[0].product.familyKey).toBe(expected.familyKey);
      if (expected.variant) expect(candidates[0].product.variant).toEqual(expected.variant);
    });
  }
});

describe("eval cases: facts the expected answers rest on", () => {
  const stats = (key: string, extra: Record<string, unknown>) =>
    t.query(internal.data.prices.getPriceStats, { productId: ids[key], now: SEED_NOW, windowDays: 365, ...extra });

  test("inflated was-price was never charged", async () => {
    const e = byId("adversarial-inflated-was").extract;
    const s = await stats("airpods-pro-3", { currentPrice: e.currentPrice, originalPrice: e.originalPrice });
    expect(s.wasPrice).toMatchObject({ timesChargedAtOrAbove: 0, typicalPrice: 249, claimedDiscountPct: 0.233, realDiscountVsTypicalPct: 0.076 });
    expect(s.overall.prices!.max).toBe(249);
  });

  test("Ember scan price is below the three observed prices", async () => {
    const s = await stats("ember-mug-2-10oz", { currentPrice: 89.99 });
    expect(s.overall.observationCount).toBe(3);
    expect(s.overall.current).toMatchObject({ isNewLow: true, percentile: 0 });
  });

  test("256GB iPad: last Black Friday low and October price", async () => {
    const p = await t.query(internal.data.prices.findPromoPatterns, { productId: ids["ipad-a16-256"], now: SEED_NOW });
    const bf = p.upcoming.find((u) => u.name === "Black Friday 2026")!;
    expect(bf.pastSales.map((s) => s.minPrice).sort()).toEqual([379, 379.99]);
    expect(p.episodes.some((e) => e.minPrice === 499.99 && e.events.length === 0)).toBe(true);
  });

  test("Walmart Ninja is out of stock and typically $75", async () => {
    const recent = await stats("ninja-af101", { windowDays: 3, retailerSlug: "walmart" });
    expect(recent.overall.observationCount).toBe(0);
    const s = await stats("ninja-af101", { windowDays: 90, retailerSlug: "walmart", currentPrice: 75, originalPrice: 99.99 });
    expect(s.wasPrice).toMatchObject({ typicalPrice: 75, timesChargedAtOrAbove: 0 });
  });

  test("missing-price case: latest stored Target price", async () => {
    const h = await t.query(internal.data.prices.getPriceHistory, { productId: ids["airpods-pro-3"], retailerSlug: "target", from: SEED_NOW - DAY, to: SEED_NOW });
    expect(h.points.at(-1)!.price).toBe(179.99);
  });
});
