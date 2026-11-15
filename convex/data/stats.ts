// Pure price math. No Convex imports, so the numbers are exact, deterministic, and unit-tested.

export type PricePoint = {
  retailerSlug: string;
  price?: number;
  originalPrice?: number;
  inStock: boolean;
  observedAt: number;
  source: string;
};

export type PricedPoint = PricePoint & { price: number };

export const DAY = 24 * 60 * 60 * 1000;

export const round2 = (n: number) => Math.round(n * 100) / 100;
const round3 = (n: number) => Math.round(n * 1000) / 1000;

export function priced(points: PricePoint[]): PricedPoint[] {
  return points.filter((p): p is PricedPoint => p.inStock && typeof p.price === "number");
}

// Linear interpolation between closest ranks; sorted must be ascending and non-empty.
export function percentile(sorted: number[], p: number): number {
  if (sorted.length === 1) return sorted[0];
  const rank = Math.min(Math.max(p, 0), 1) * (sorted.length - 1);
  const lo = Math.floor(rank);
  const hi = Math.ceil(rank);
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (rank - lo);
}

// Where x sits among observed prices: 0 = below every observation, 1 = above every one. Ties count half.
export function percentileRank(values: number[], x: number): number {
  const below = values.filter((v) => v < x - 0.005).length;
  const equal = values.filter((v) => Math.abs(v - x) <= 0.005).length;
  return round3((below + equal / 2) / values.length);
}

export function median(values: number[]): number {
  return percentile([...values].sort((a, b) => a - b), 0.5);
}

export type PriceSummary = ReturnType<typeof summarize>;

export function summarize(points: PricePoint[], currentPrice?: number) {
  const inStock = priced(points).sort((a, b) => a.observedAt - b.observedAt);
  const outOfStockCount = points.length - inStock.length;
  const sources: Record<string, number> = {};
  for (const p of points) sources[p.source] = (sources[p.source] ?? 0) + 1;
  if (inStock.length === 0) {
    return { observationCount: 0, outOfStockCount, sources, prices: null, current: null };
  }
  const values = inStock.map((p) => p.price);
  const sorted = [...values].sort((a, b) => a - b);
  const mean = values.reduce((s, v) => s + v, 0) / values.length;
  const min = sorted[0];
  const lowest = inStock.filter((p) => Math.abs(p.price - min) <= 0.005);
  const latest = inStock[inStock.length - 1];
  const first = inStock[0];
  const now = currentPrice ?? latest.price;
  return {
    observationCount: inStock.length,
    outOfStockCount,
    sources,
    prices: {
      mean: round2(mean),
      median: round2(percentile(sorted, 0.5)),
      min: round2(min),
      max: round2(sorted[sorted.length - 1]),
      p10: round2(percentile(sorted, 0.1)),
      p25: round2(percentile(sorted, 0.25)),
      p75: round2(percentile(sorted, 0.75)),
      p90: round2(percentile(sorted, 0.9)),
      minFirstSeenAt: lowest[0].observedAt,
      minLastSeenAt: lowest[lowest.length - 1].observedAt,
      minRetailers: [...new Set(lowest.map((p) => p.retailerSlug))].sort(),
      firstObservedAt: first.observedAt,
      lastObservedAt: latest.observedAt,
      spanDays: Math.round((latest.observedAt - first.observedAt) / DAY),
      latest: { price: latest.price, retailerSlug: latest.retailerSlug, observedAt: latest.observedAt },
    },
    current: {
      price: now,
      percentile: percentileRank(values, now),
      vsMedianPct: round3(now / percentile(sorted, 0.5) - 1),
      vsMinPct: round3(now / min - 1),
      isNewLow: now < min - 0.005,
      atOrBelowLow: now <= min + 0.005,
    },
  };
}

// How often the retailer's claimed "was" price was actually charged in the window.
export function wasPriceCheck(points: PricePoint[], originalPrice: number, currentPrice?: number) {
  const inStock = priced(points);
  const tolerance = originalPrice * 0.02;
  const atOrAbove = inStock.filter((p) => p.price >= originalPrice - tolerance);
  const values = inStock.map((p) => p.price);
  const typical = values.length ? median(values) : null;
  return {
    originalPrice,
    observationCount: inStock.length,
    timesChargedAtOrAbove: atOrAbove.length,
    shareChargedAtOrAbove: inStock.length ? round3(atOrAbove.length / inStock.length) : null,
    lastChargedAt: atOrAbove.length ? Math.max(...atOrAbove.map((p) => p.observedAt)) : null,
    typicalPrice: typical === null ? null : round2(typical),
    claimedDiscountPct:
      currentPrice === undefined ? null : round3(1 - currentPrice / originalPrice),
    realDiscountVsTypicalPct:
      currentPrice === undefined || typical === null ? null : round3(1 - currentPrice / typical),
  };
}

export type SaleEpisode = {
  retailerSlug: string;
  startAt: number;
  endAt: number;
  minPrice: number;
  depthPct: number;
  baseline: number;
  pointCount: number;
  ongoing: boolean;
  claimedOriginalPrice: number | null;
  preSaleHikePct: number | null;
  preSaleHike: boolean;
};

export type ClaimedDiscount = {
  retailerSlug: string;
  startAt: number;
  endAt: number;
  ongoing: boolean;
  minPrice: number;
  claimedOriginalPrice: number;
  claimedPct: number;
  typicalBefore: number | null;
  realPct: number | null;
  wasChargedShareBefore: number | null;
  wasRarelyCharged: boolean;
  preSaleHikePct: number | null;
  preSaleHike: boolean;
};

const SALE_DEPTH = 0.07;
const BASELINE_DAYS = 60;
const PRE_SALE_DAYS = 21;
const HIKE_THRESHOLD = 0.05;
const MIN_BASELINE_POINTS = 5;
const RARELY_CHARGED = 0.25;

function byRetailer(points: PricePoint[]) {
  const groups = new Map<string, PricedPoint[]>();
  for (const p of priced(points)) {
    const list = groups.get(p.retailerSlug) ?? [];
    list.push(p);
    groups.set(p.retailerSlug, list);
  }
  for (const list of groups.values()) list.sort((a, b) => a.observedAt - b.observedAt);
  return groups;
}

const pricesBetween = (list: PricedPoint[], from: number, to: number) =>
  list.filter((p) => p.observedAt >= from && p.observedAt < to).map((p) => p.price);

// Typical price just before t: median of the previous 60 days, or null when too few points.
function baselineAt(list: PricedPoint[], t: number): number | null {
  const prior = pricesBetween(list, t - BASELINE_DAYS * DAY, t);
  return prior.length >= MIN_BASELINE_POINTS ? median(prior) : null;
}

// Pre-sale hike: the 21 days before startAt averaged at least 5% above the 60 days before that.
function preSaleHike(list: PricedPoint[], startAt: number) {
  const recent = pricesBetween(list, startAt - PRE_SALE_DAYS * DAY, startAt);
  const earlier = pricesBetween(list, startAt - (PRE_SALE_DAYS + BASELINE_DAYS) * DAY, startAt - PRE_SALE_DAYS * DAY);
  if (recent.length === 0 || earlier.length < MIN_BASELINE_POINTS) return { pct: null, hike: false };
  const pct = recent.reduce((s, x) => s + x, 0) / recent.length / median(earlier) - 1;
  return { pct: round3(pct), hike: pct >= HIKE_THRESHOLD };
}

// Group consecutive points that pass a test into runs, per retailer.
function runs(list: PricedPoint[], test: (p: PricedPoint) => boolean) {
  const out: PricedPoint[][] = [];
  let run: PricedPoint[] = [];
  for (const p of list) {
    if (test(p)) run.push(p);
    else if (run.length) {
      out.push(run);
      run = [];
    }
  }
  if (run.length) out.push(run);
  return out;
}

// Sale episode: consecutive points at least 7% under the typical price of the 60 days before.
// A rolling baseline keeps permanent price changes (an MSRP increase) from looking like sales.
export function findSaleEpisodes(points: PricePoint[]): SaleEpisode[] {
  const episodes: SaleEpisode[] = [];
  for (const [retailerSlug, list] of byRetailer(points)) {
    const last = list[list.length - 1];
    for (const run of runs(list, (p) => {
      const b = baselineAt(list, p.observedAt);
      return b !== null && p.price <= b * (1 - SALE_DEPTH);
    })) {
      const startAt = run[0].observedAt;
      const baseline = baselineAt(list, startAt)!;
      const minPrice = Math.min(...run.map((p) => p.price));
      const claimed = run.map((p) => p.originalPrice).filter((x): x is number => x !== undefined);
      const hike = preSaleHike(list, startAt);
      episodes.push({
        retailerSlug,
        startAt,
        endAt: run[run.length - 1].observedAt,
        minPrice: round2(minPrice),
        depthPct: round3(1 - minPrice / baseline),
        baseline: round2(baseline),
        pointCount: run.length,
        ongoing: run[run.length - 1] === last,
        claimedOriginalPrice: claimed.length ? Math.max(...claimed) : null,
        preSaleHikePct: hike.pct,
        preSaleHike: hike.hike,
      });
    }
  }
  return episodes.sort((a, b) => a.startAt - b.startAt || a.retailerSlug.localeCompare(b.retailerSlug));
}

// Every stretch where a retailer showed a crossed-out "was" price, checked against what it actually charged
// in the 90 days before: how often the "was" price was real, and the real saving versus the typical price.
export function findClaimedDiscounts(points: PricePoint[]): ClaimedDiscount[] {
  const out: ClaimedDiscount[] = [];
  for (const [retailerSlug, list] of byRetailer(points)) {
    const last = list[list.length - 1];
    for (const run of runs(list, (p) => p.originalPrice !== undefined && p.originalPrice > p.price)) {
      const startAt = run[0].observedAt;
      const claimedOriginalPrice = Math.max(...run.map((p) => p.originalPrice!));
      const minPrice = Math.min(...run.map((p) => p.price));
      const before = pricesBetween(list, startAt - 90 * DAY, startAt);
      const typical = before.length >= MIN_BASELINE_POINTS ? median(before) : null;
      const charged = before.length
        ? before.filter((x) => x >= claimedOriginalPrice * 0.98).length / before.length
        : null;
      const hike = preSaleHike(list, startAt);
      out.push({
        retailerSlug,
        startAt,
        endAt: run[run.length - 1].observedAt,
        ongoing: run[run.length - 1] === last,
        minPrice: round2(minPrice),
        claimedOriginalPrice,
        claimedPct: round3(1 - minPrice / claimedOriginalPrice),
        typicalBefore: typical === null ? null : round2(typical),
        realPct: typical === null ? null : round3(1 - minPrice / typical),
        wasChargedShareBefore: charged === null ? null : round3(charged),
        wasRarelyCharged: charged !== null && before.length >= MIN_BASELINE_POINTS && charged < RARELY_CHARGED,
        preSaleHikePct: hike.pct,
        preSaleHike: hike.hike,
      });
    }
  }
  return out.sort((a, b) => a.startAt - b.startAt || a.retailerSlug.localeCompare(b.retailerSlug));
}
