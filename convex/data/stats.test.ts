import { describe, expect, test } from "vitest";
import { DAY, findClaimedDiscounts, findSaleEpisodes, percentile, percentileRank, summarize, wasPriceCheck, type PricePoint } from "./stats";

const T0 = Date.UTC(2026, 0, 1);
const pt = (dayIndex: number, price: number | undefined, extra: Partial<PricePoint> = {}): PricePoint => ({
  retailerSlug: "target",
  price,
  inStock: price !== undefined,
  observedAt: T0 + dayIndex * DAY,
  source: "seed",
  ...extra,
});

describe("percentiles", () => {
  test("interpolates between ranks", () => {
    expect(percentile([10, 20, 30, 40], 0.5)).toBe(25);
    expect(percentile([10, 20, 30, 40], 0.1)).toBeCloseTo(13);
    expect(percentile([7], 0.9)).toBe(7);
  });

  test("rank counts ties as half", () => {
    expect(percentileRank([10, 20, 20, 30], 20)).toBe(0.5);
    expect(percentileRank([10, 20, 30], 5)).toBe(0);
    expect(percentileRank([10, 20, 30], 35)).toBe(1);
  });
});

describe("summarize", () => {
  test("ignores out-of-stock points instead of treating them as zero", () => {
    const s = summarize([pt(0, 100), pt(1, undefined), pt(2, 80), pt(3, 90)], 85);
    expect(s.observationCount).toBe(3);
    expect(s.outOfStockCount).toBe(1);
    expect(s.prices).toMatchObject({ min: 80, max: 100, median: 90, mean: 90 });
    expect(s.current).toMatchObject({ price: 85, percentile: 0.333, isNewLow: false });
  });

  test("reports an empty window without inventing numbers", () => {
    const s = summarize([pt(0, undefined)]);
    expect(s.prices).toBeNull();
    expect(s.current).toBeNull();
  });
});

test("was-price check counts how often the claimed price was really charged", () => {
  const points = [...Array(9)].map((_, i) => pt(i, 80)).concat([pt(9, 100)]);
  const w = wasPriceCheck(points, 100, 75);
  expect(w.timesChargedAtOrAbove).toBe(1);
  expect(w.shareChargedAtOrAbove).toBe(0.1);
  expect(w.claimedDiscountPct).toBe(0.25);
  expect(w.realDiscountVsTypicalPct).toBe(0.063);
});

describe("sale episodes", () => {
  test("a permanent price increase is not a sale, but a dip after it is", () => {
    const points: PricePoint[] = [];
    for (let d = 0; d < 90; d += 3) points.push(pt(d, 349));
    for (let d = 90; d < 200; d += 3) points.push(pt(d, 449));
    for (let d = 200; d < 204; d++) points.push(pt(d, 399));
    for (let d = 204; d < 220; d += 3) points.push(pt(d, 449));
    const episodes = findSaleEpisodes(points);
    expect(episodes).toHaveLength(1);
    expect(episodes[0]).toMatchObject({ minPrice: 399, baseline: 449, depthPct: 0.111, ongoing: false });
  });

  test("flags a price hike in the three weeks before a claimed discount", () => {
    const points: PricePoint[] = [];
    for (let d = 0; d < 80; d += 3) points.push(pt(d, 79.99));
    for (let d = 80; d < 101; d += 3) points.push(pt(d, 99.99));
    for (let d = 101; d < 106; d++) points.push(pt(d, 74.99, { originalPrice: 99.99 }));
    const [claim] = findClaimedDiscounts(points);
    expect(claim).toMatchObject({
      claimedOriginalPrice: 99.99,
      claimedPct: 0.25,
      ongoing: true,
      preSaleHike: true,
      typicalBefore: 79.99,
      realPct: 0.063,
    });
    expect(findSaleEpisodes(points)).toHaveLength(0);
  });
});
