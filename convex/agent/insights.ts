import type { Evidence } from "./evidence";

// Presented shapes (see port.ts present()): dates are ISO strings, fractions are percents.
type Prices = { median: number; min: number; latest: { price: number; retailerSlug: string; observedAt: string } };
type Summary = { observationCount: number; prices: Prices | null; current: { price: number } | null };
type Stats = {
  overall: Summary;
  perRetailer: (Summary & { retailerSlug: string })[];
  wasPrice: { originalPrice: number; shareChargedAtOrAbovePercent: number | null; claimedDiscountPercent: number | null; realDiscountVsTypicalPercent: number | null } | null;
};
type Episode = { retailerSlug: string; startAt: string; endAt: string; minPrice: number; depthPercent: number; ongoing: boolean; preSaleHike: boolean; preSaleHikePercent: number | null; events: { name: string }[] };
type Claimed = { retailerSlug: string; startAt: string; ongoing: boolean; minPrice: number; claimedOriginalPrice: number; claimedPercent: number; realPercent: number | null; wasRarelyCharged: boolean; preSaleHike: boolean; preSaleHikePercent: number | null };
type Upcoming = { name: string; startsAt: string; endsAt: string; daysAway: number; dateConfidence: string; pastSales: { retailerSlug: string; startAt: string; minPrice: number }[] };
export type Promo = { episodes: Episode[]; claimedDiscounts: Claimed[]; upcoming: Upcoming[]; recurrence: { episodeCount: number; medianGapDays: number | null } };
type Competitor = { productId: string; title: string; brand: string; specs: Record<string, string | number | boolean>; similarity: number; last90Days: { observationCount: number; latestPrice: number | null; latestRetailer: string | null } };
type Specs = Record<string, string | number | boolean>;

const round2 = (n: number) => Math.round(n * 100) / 100;
const pctOf = (part: number, whole: number) => Math.round((part / whole) * 1000) / 10;
const medianOf = (xs: number[]) => {
  const s = [...xs].sort((a, b) => a - b);
  return s.length % 2 ? s[(s.length - 1) / 2] : (s[s.length / 2 - 1] + s[s.length / 2]) / 2;
};
const DAY = 86_400_000;
const addDays = (iso: string, days: number) => new Date(Date.parse(iso) + days * DAY).toISOString().slice(0, 10);

export type Forecast = {
  outlook: "better_price_likely" | "better_price_possible" | "no_better_price_expected" | "unknown";
  low: number | null;
  high: number | null;
  byDate: string | null;
  basedOn: "past_event_editions" | "sale_cycle" | "none";
  eventName: string | null;
  pastEditions: number;
  confidence: number;
  savingsAtLow: number | null;
  savingsAtLowPercent: number | null;
};

// Will a better price come? The range is the lows this product hit at past editions of an upcoming event,
// or failing that at its own recurring sales. Confidence grows with past editions and with how many retailers
// beat today's price at them; a better price is "likely" when two editions or two retailers did.
export function forecastPrice(promo: Promo | undefined, current: number | null, today: string, horizonDays = 45): Forecast {
  const none: Forecast = { outlook: "unknown", low: null, high: null, byDate: null, basedOn: "none", eventName: null, pastEditions: 0, confidence: 0, savingsAtLow: null, savingsAtLowPercent: null };
  if (!promo || current === null) return none;
  const range = (lows: number[]) => ({ low: Math.min(...lows), high: Math.max(...lows), savingsAtLow: round2(current - Math.min(...lows)), savingsAtLowPercent: pctOf(current - Math.min(...lows), current) });
  const outlook = (low: number, confident: boolean): Forecast["outlook"] => (low > current * 0.95 ? "no_better_price_expected" : confident ? "better_price_likely" : "better_price_possible");
  const events = promo.upcoming.filter((e) => e.pastSales.length > 0 && e.daysAway <= horizonDays);
  if (events.length) {
    const lows = events.flatMap((e) => e.pastSales.map((s) => s.minPrice));
    const event = events.find((e) => e.pastSales.some((s) => s.minPrice === Math.min(...lows)))!;
    const past = event.pastSales;
    const editions = new Set(past.map((s) => s.startAt.slice(0, 7))).size;
    const retailersBeatingToday = new Set(past.filter((s) => s.minPrice <= current * 0.95).map((s) => s.retailerSlug)).size;
    const confidence = Math.min(0.8, 0.35 + 0.15 * Math.min(editions, 3) + (retailersBeatingToday >= 2 ? 0.1 : 0) - (event.dateConfidence === "confirmed" ? 0 : 0.1));
    const r = range(past.map((s) => s.minPrice));
    return { ...r, outlook: outlook(r.low, editions >= 2 || retailersBeatingToday >= 2), byDate: event.endsAt, basedOn: "past_event_editions", eventName: event.name, pastEditions: editions, confidence: round2(confidence) };
  }
  const episodes = promo.episodes.filter((e) => !e.ongoing);
  const gap = promo.recurrence.medianGapDays;
  if (episodes.length >= 3 && gap !== null && gap > 0) {
    const recent = episodes.slice(-4).map((e) => e.minPrice);
    const r = range(recent);
    let next = addDays(episodes[episodes.length - 1].startAt, gap);
    while (next < today) next = addDays(next, gap);
    return { ...r, outlook: outlook(r.low, false), byDate: next, basedOn: "sale_cycle", eventName: null, pastEditions: episodes.length, confidence: round2(Math.min(0.55, 0.25 + 0.05 * episodes.length)) };
  }
  return none;
}

// How each retailer prices and discounts this product.
export function retailerPatterns(stats: Stats, promo: Promo | undefined) {
  return stats.perRetailer
    .filter((r) => r.prices)
    .map((r) => {
      const eps = (promo?.episodes ?? []).filter((e) => e.retailerSlug === r.retailerSlug);
      const claims = (promo?.claimedDiscounts ?? []).filter((c) => c.retailerSlug === r.retailerSlug);
      return {
        retailer: r.retailerSlug,
        latestPrice: r.prices!.latest.price,
        latestSeen: r.prices!.latest.observedAt,
        typicalPrice: r.prices!.median,
        lowestPrice: r.prices!.min,
        observationCount: r.observationCount,
        saleEpisodes: eps.length,
        medianSaleDepthPercent: eps.length ? round2(medianOf(eps.map((e) => e.depthPercent))) : null,
        deepestSalePrice: eps.length ? Math.min(...eps.map((e) => e.minPrice)) : null,
        lastSaleStarted: eps.length ? eps[eps.length - 1].startAt : null,
        advertisedDiscounts: claims.length,
        advertisedWithRarelyChargedWasPrice: claims.filter((c) => c.wasRarelyCharged).length,
        priceRaisedBeforeSale: new Set([...eps, ...claims].filter((e) => e.preSaleHike).map((e) => e.startAt)).size,
      };
    })
    .sort((a, b) => a.latestPrice - b.latestPrice);
}

// Is the advertised discount real: was-price history, repeated discounting, and price hikes before sales.
export function discountAuthenticity(stats: Stats, promo: Promo | undefined) {
  const was = stats.wasPrice;
  const hikes = [
    ...(promo?.episodes ?? []).filter((e) => e.preSaleHike).map((e) => ({ retailer: e.retailerSlug, saleStarted: e.startAt, hikePercent: e.preSaleHikePercent })),
    ...(promo?.claimedDiscounts ?? []).filter((c) => c.preSaleHike).map((c) => ({ retailer: c.retailerSlug, saleStarted: c.startAt, hikePercent: c.preSaleHikePercent })),
  ];
  const seen = new Set<string>();
  const preSaleHikes = hikes.filter((h) => !seen.has(h.retailer + h.saleStarted) && seen.add(h.retailer + h.saleStarted)).sort((a, b) => a.saleStarted.localeCompare(b.saleStarted));
  const rec = promo?.recurrence ?? { episodeCount: 0, medianGapDays: null };
  const claims = promo?.claimedDiscounts ?? [];
  return {
    claimedWasPrice: was?.originalPrice ?? null,
    wasPriceChargedSharePercent: was?.shareChargedAtOrAbovePercent ?? null,
    claimedDiscountPercent: was?.claimedDiscountPercent ?? null,
    realDiscountVsTypicalPercent: was?.realDiscountVsTypicalPercent ?? null,
    saleEpisodes12Months: rec.episodeCount,
    medianDaysBetweenSales: rec.medianGapDays,
    discountingIsRoutine: rec.medianGapDays !== null && rec.medianGapDays <= 21 && rec.episodeCount >= 6,
    pastAdvertisedDiscounts: claims.length,
    pastAdvertisedWithRarelyChargedWasPrice: claims.filter((c) => c.wasRarelyCharged).length,
    preSaleHikes,
  };
}

// Competitors side by side with this product: price gap and which key specs match.
export function compareCompetitors(specs: Specs, current: number | null, competitors: Competitor[]) {
  return competitors
    .filter((c) => c.last90Days.latestPrice !== null)
    .map((c) => {
      const keys = [...new Set([...Object.keys(specs), ...Object.keys(c.specs)])].sort();
      const rows = keys.map((key) => ({ key, thisProduct: specs[key] ?? null, competitor: c.specs[key] ?? null, same: specs[key] !== undefined && String(specs[key]).toLowerCase() === String(c.specs[key]).toLowerCase() }));
      const shared = rows.filter((r) => r.thisProduct !== null && r.competitor !== null);
      const price = c.last90Days.latestPrice!;
      return {
        productId: c.productId,
        title: c.title,
        brand: c.brand,
        latestPrice: price,
        retailer: c.last90Days.latestRetailer,
        observations90Days: c.last90Days.observationCount,
        similarityPercent: Math.round(c.similarity * 1000) / 10,
        savingsVsCurrent: current === null ? null : round2(current - price),
        savingsPercent: current === null ? null : pctOf(current - price, current),
        matchingSpecsPercent: shared.length ? Math.round((shared.filter((r) => r.same).length / shared.length) * 100) : null,
        specs: rows,
      };
    });
}

// The deterministic report sections, stored as one evidence item so the model and the phone see the same numbers.
export function buildInsights(input: { stats: Evidence; promo: Evidence; competitors: Evidence; specs: Specs; today: string }) {
  const stats = input.stats.result as Stats;
  const promo = input.promo.result as Promo;
  const current = stats.overall.current?.price ?? null;
  return {
    forecast: forecastPrice(promo, current, input.today),
    retailerPatterns: retailerPatterns(stats, promo),
    discountAuthenticity: discountAuthenticity(stats, promo),
    competitorComparison: compareCompetitors(input.specs, current, (input.competitors.result as Competitor[]) ?? []),
  };
}

export type Insights = ReturnType<typeof buildInsights>;
