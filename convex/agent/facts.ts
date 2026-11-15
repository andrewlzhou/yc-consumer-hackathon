import type { Evidence } from "./evidence";

const round2 = (n: number) => Math.round(n * 100) / 100;
const pctOf = (part: number, whole: number) => Math.round((part / whole) * 1000) / 10;

type Summary = { observationCount: number; prices: { median: number; min: number; minLastSeenAt: string; spanDays: number; latest: { price: number; retailerSlug: string; observedAt: string } } | null; current: { price: number } | null };
type Stats = { overall: Summary; perRetailer: (Summary & { retailerSlug: string })[]; wasPrice: { originalPrice: number; shareChargedAtOrAbovePercent: number | null; claimedDiscountPercent: number | null; realDiscountVsTypicalPercent: number | null } | null; isSampleData: boolean };
type Promo = {
  claimedDiscounts: { retailerSlug: string; ongoing: boolean; preSaleHike: boolean; preSaleHikePercent: number | null; wasRarelyCharged: boolean; wasChargedShareBeforePercent: number | null }[];
  upcoming: { name: string; startsAt: string; daysAway: number; retailerSlug: string | null; pastSales: { minPrice: number; retailerSlug: string }[] }[];
  recurrence: { episodeCount: number; medianGapDays: number | null };
};
type Competitor = { productId: string; title: string; brand: string; last90Days: { observationCount: number; latestPrice: number | null; latestRetailer: string | null } };

// The comparisons a shopper cares about, computed exactly from the other evidence, so a small model can cite
// savings and gaps instead of doing arithmetic.
export function keyFacts(scanRetailer: string, stats: Evidence, recentStats: Evidence, promo: Evidence, competitors: Evidence) {
  const s = stats.result as Stats;
  const recent = (recentStats.result as Stats).overall.prices;
  const p = promo.result as Promo;
  const c = (competitors.result as Competitor[]) ?? [];
  const o = s.overall;
  if (!o.prices || !o.current) return { enoughHistory: false, observationCount: o.observationCount, isSampleData: s.isSampleData };
  const current = o.current.price;
  const saving = (price: number) => ({ savingsVsCurrent: round2(current - price), savingsPercent: pctOf(current - price, current) });
  const ongoing = p.claimedDiscounts.find((d) => d.ongoing && d.retailerSlug === scanRetailer);
  const cheapestNow = s.perRetailer.filter((r) => r.prices).sort((a, b) => a.prices!.latest.price - b.prices!.latest.price)[0];
  return {
    enoughHistory: o.observationCount >= 5 && o.prices.spanDays >= 30,
    isSampleData: s.isSampleData,
    observationCount: o.observationCount,
    spanDays: o.prices.spanDays,
    currentPrice: current,
    typicalPrice12Months: o.prices.median,
    currentMinusTypical12Months: round2(current - o.prices.median),
    typicalPrice90Days: recent?.median ?? null,
    currentMinusTypical90Days: recent ? round2(current - recent.median) : null,
    lowestPrice90Days: recent?.min ?? null,
    lowestPrice: o.prices.min,
    lowestPriceLastSeen: o.prices.minLastSeenAt,
    currentMinusLowest: round2(current - o.prices.min),
    withinThreePercentOfLowest: current <= o.prices.min * 1.03,
    claimedWasPrice: s.wasPrice && {
      wasPrice: s.wasPrice.originalPrice,
      chargedAtOrAboveSharePercent: s.wasPrice.shareChargedAtOrAbovePercent,
      claimedDiscountPercent: s.wasPrice.claimedDiscountPercent,
      realDiscountVsTypicalPercent: s.wasPrice.realDiscountVsTypicalPercent,
    },
    saleAtThisRetailer: ongoing && { priceRaisedBeforeSale: ongoing.preSaleHike, preSaleHikePercent: ongoing.preSaleHikePercent, wasPriceRarelyCharged: ongoing.wasRarelyCharged },
    saleEpisodesLast12Months: p.recurrence.episodeCount,
    medianDaysBetweenSales: p.recurrence.medianGapDays,
    upcomingEvents: p.upcoming
      .filter((e) => e.pastSales.length > 0)
      .map((e) => {
        const low = Math.min(...e.pastSales.map((x) => x.minPrice));
        return { name: e.name, startsAt: e.startsAt, daysAway: e.daysAway, lowestPriceAtPastEditions: low, ...saving(low), pastEditionsBeatTodayBy5Percent: low <= current * 0.95 };
      }),
    cheapestRetailerNow: cheapestNow && { retailer: cheapestNow.retailerSlug, price: cheapestNow.prices!.latest.price, seenAt: cheapestNow.prices!.latest.observedAt, ...saving(cheapestNow.prices!.latest.price) },
    comparablesFromCatalog: c
      .filter((x) => x.last90Days.latestPrice !== null)
      .map((x) => ({ productId: x.productId, title: x.title, latestPrice: x.last90Days.latestPrice!, retailer: x.last90Days.latestRetailer, ...saving(x.last90Days.latestPrice!), atLeast20PercentCheaper: x.last90Days.latestPrice! <= current * 0.8 })),
  };
}
