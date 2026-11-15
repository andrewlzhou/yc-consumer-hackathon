import type { Evidence } from "./evidence";
import type { AgentOutput, Verdict } from "./output";

// Presented shapes (see port.ts present()): dates are ISO strings, fractions are percents.
type Summary = {
  observationCount: number;
  prices: { median: number; mean: number; min: number; spanDays: number; minLastSeenAt: string; latest: { price: number; retailerSlug: string } } | null;
  current: { price: number; percentileRankPercent: number; vsMedianPercent: number; vsMinPercent: number; atOrBelowLow: boolean } | null;
};
type Stats = {
  overall: Summary;
  perRetailer: (Summary & { retailerSlug: string })[];
  wasPrice: { originalPrice: number; shareChargedAtOrAbovePercent: number | null; typicalPrice: number | null; claimedDiscountPercent: number | null; realDiscountVsTypicalPercent: number | null } | null;
};
type Promo = {
  recurrence: { episodeCount: number; medianGapDays: number | null };
  claimedDiscounts: { retailerSlug: string; ongoing: boolean; claimedOriginalPrice: number; preSaleHike: boolean; preSaleHikePercent: number | null; wasRarelyCharged: boolean; typicalBefore: number | null }[];
  upcoming: { name: string; startsAt: string; daysAway: number; ongoing: boolean; pastSales: { minPrice: number }[] }[];
};
type Competitor = { productId: string; title: string; brand: string; last90Days: { observationCount: number; latestPrice: number | null } };

export type HeuristicInput = {
  productId: string;
  retailer: string;
  stats?: Evidence;
  promo?: Evidence;
  competitors?: Evidence;
};

const usd = (n: number) => `$${n.toFixed(2)}`;
const pct = (n: number) => `${Math.round(Math.abs(n))}%`;
const ids = (...items: (Evidence | undefined)[]) => items.filter((e): e is Evidence => !!e).map((e) => e.id);

export const MIN_OBSERVATIONS = 5;
export const MIN_SPAN_DAYS = 30;

export function isThin(stats: unknown): boolean {
  const o = (stats as Stats | undefined)?.overall;
  return !o?.prices || !o.current || o.observationCount < MIN_OBSERVATIONS || o.prices.spanDays < MIN_SPAN_DAYS;
}

// Deterministic analyst over the same evidence the model sees. It backs the fake provider and is the fallback
// when the model fails or is ungrounded, so its text only states numbers copied from evidence.
export function heuristicAnalysis(input: HeuristicInput): AgentOutput {
  const stats = input.stats?.result as Stats | undefined;
  const promo = input.promo?.result as Promo | undefined;
  const competitors = (input.competitors?.result as Competitor[] | undefined) ?? [];
  const empty = { evidenceIds: [] as string[] };
  const base: AgentOutput = {
    match: { productId: input.productId, confidence: 0.8, note: "Matched in catalog" },
    verdict: "INVESTIGATE",
    confidence: 0.3,
    reason: "",
    reasonEvidenceIds: [],
    priceAssessment: { summary: "Not enough price history to judge this price.", evidenceIds: ids(input.stats) },
    discount: { status: stats?.wasPrice ? "unclear" : "no_discount_claimed", signals: [], explanation: "Not enough history to check the discount.", ...empty },
    forecast: { low: null, high: null, byDate: null, confidence: 0, explanation: "No basis for a forecast.", ...empty },
    retailers: { summary: "No retailer comparison available.", ...empty },
    competitors: [],
    recommendation: { reasoning: "", ...empty },
  };

  if (!stats || isThin(stats)) {
    const n = stats?.overall.observationCount ?? 0;
    const why = `We have only ${n} price observations for this product, too few to judge this price.`;
    return { ...base, reason: why, reasonEvidenceIds: ids(input.stats), recommendation: { reasoning: `${why} We'll keep tracking it.`, evidenceIds: ids(input.stats) } };
  }
  const o = stats.overall;
  const prices = o.prices!;
  const cur = o.current!;
  const current = cur.price;

  const priceAssessment = {
    summary: `At ${usd(current)}, this is ${pct(cur.vsMedianPercent)} ${cur.vsMedianPercent <= 0 ? "below" : "above"} the typical ${usd(prices.median)}; the lowest seen was ${usd(prices.min)}.`,
    evidenceIds: ids(input.stats),
  };

  const signals: AgentOutput["discount"]["signals"] = [];
  const parts: string[] = [];
  const was = stats.wasPrice;
  const ongoing = promo?.claimedDiscounts.find((c) => c.ongoing && c.retailerSlug === input.retailer);
  if (was && was.shareChargedAtOrAbovePercent !== null && was.shareChargedAtOrAbovePercent < 25) {
    signals.push("was_price_rarely_seen");
    parts.push(`the was-price of ${usd(was.originalPrice)} was charged in only ${pct(was.shareChargedAtOrAbovePercent)} of observations`);
  }
  if (ongoing?.preSaleHike && ongoing.preSaleHikePercent !== null) {
    signals.push("price_raised_before_sale");
    parts.push(`the price was raised ${pct(ongoing.preSaleHikePercent)} in the weeks before this sale`);
  }
  if (promo && promo.recurrence.medianGapDays !== null && promo.recurrence.medianGapDays <= 21 && promo.recurrence.episodeCount >= 6) {
    signals.push("sale_price_is_normal_price");
    parts.push(`it goes on sale every ${promo.recurrence.medianGapDays} days or so`);
  }
  if (was && was.claimedDiscountPercent !== null && was.realDiscountVsTypicalPercent !== null && was.claimedDiscountPercent >= 15 && was.realDiscountVsTypicalPercent < 5) {
    signals.push("small_real_savings");
    parts.push(`the claimed ${pct(was.claimedDiscountPercent)} off is only ${pct(was.realDiscountVsTypicalPercent)} below the typical price`);
  }
  const genuine = was && (was.realDiscountVsTypicalPercent ?? 0) >= 5;
  const discount: AgentOutput["discount"] = !was
    ? { status: "no_discount_claimed", signals: [], explanation: "No discount is advertised.", evidenceIds: ids(input.stats) }
    : signals.length
      ? { status: "misleading", signals, explanation: `The discount looks misleading: ${parts.join("; ")}.`, evidenceIds: ids(input.stats, input.promo) }
      : genuine
        ? { status: "genuine", signals: [], explanation: `The discount is real: ${pct(was.realDiscountVsTypicalPercent!)} below the typical ${usd(was.typicalPrice!)}.`, evidenceIds: ids(input.stats) }
        : { status: "unclear", signals: [], explanation: "The advertised price is close to the typical price, so the savings are small.", evidenceIds: ids(input.stats) };

  const soon = (promo?.upcoming ?? []).filter((e) => e.daysAway <= 21 && e.pastSales.length > 0);
  const lows = soon.flatMap((e) => e.pastSales.map((s) => s.minPrice));
  const event = soon.find((e) => e.pastSales.some((s) => s.minPrice === Math.min(...lows)));
  const forecast: AgentOutput["forecast"] = event
    ? { low: Math.min(...lows), high: Math.max(...lows), byDate: event.startsAt, confidence: lows.length >= 2 ? 0.6 : 0.4,
        explanation: `At past editions of upcoming sales this sold for ${usd(Math.min(...lows))} to ${usd(Math.max(...lows))}; ${event.name} is ${event.daysAway} days away.`, evidenceIds: ids(input.promo) }
    : base.forecast;

  const priced = stats.perRetailer.filter((r) => r.prices);
  const cheapest = [...priced].sort((a, b) => a.prices!.latest.price - b.prices!.latest.price)[0];
  const retailers = cheapest
    ? { summary: `The lowest latest price across the retailers we track is ${usd(cheapest.prices!.latest.price)} at ${cheapest.retailerSlug}.`, evidenceIds: ids(input.stats) }
    : base.retailers;

  const cheaper = competitors
    .filter((c) => c.last90Days.latestPrice !== null && c.last90Days.observationCount >= MIN_OBSERVATIONS && c.last90Days.latestPrice <= current * 0.8)
    .sort((a, b) => a.last90Days.latestPrice! - b.last90Days.latestPrice!);
  const competitorList = competitors.filter((c) => c.last90Days.latestPrice !== null).slice(0, 3).map((c) => ({
    productId: c.productId,
    title: c.title,
    valueReasoning: `${c.brand} alternative, latest ${usd(c.last90Days.latestPrice!)} versus ${usd(current)} for this one.`,
    evidenceIds: ids(input.competitors, input.stats),
  }));

  let verdict: Verdict;
  let confidence: number;
  let reason: string;
  let reasonIds: string[];
  if (cheaper[0]) {
    verdict = "CONSIDER_ALTERNATIVE";
    confidence = 0.6;
    reason = `${cheaper[0].brand}'s ${cheaper[0].title} sells for ${usd(cheaper[0].last90Days.latestPrice!)}, versus ${usd(current)} here.`;
    reasonIds = ids(input.competitors, input.stats);
  } else if (forecast.low !== null && forecast.low < current * 0.95 && event) {
    verdict = "WAIT";
    confidence = forecast.confidence;
    reason = `${event.name} is ${event.daysAway} days away, and last time this dropped to ${usd(forecast.low)}.`;
    reasonIds = ids(input.promo);
  } else if (signals.length > 0 && cur.vsMedianPercent > -5) {
    verdict = "WAIT";
    confidence = 0.55;
    reason = `This deal isn't real savings: ${usd(current)} is close to the typical ${usd(prices.median)}.`;
    reasonIds = ids(input.stats);
  } else if (cur.atOrBelowLow || cur.vsMinPercent <= 3 || cur.percentileRankPercent <= 10) {
    verdict = "BUY_NOW";
    confidence = o.observationCount >= 30 ? 0.8 : 0.65;
    reason = `${usd(current)} matches the lowest price we've seen (${usd(prices.min)}), well under the typical ${usd(prices.median)}.`;
    reasonIds = ids(input.stats);
  } else if (cur.vsMedianPercent > 0) {
    verdict = "WAIT";
    confidence = 0.5;
    reason = `${usd(current)} is ${pct(cur.vsMedianPercent)} above the typical ${usd(prices.median)}.`;
    reasonIds = ids(input.stats);
  } else {
    verdict = "BUY_NOW";
    confidence = 0.55;
    reason = `${usd(current)} is ${pct(cur.vsMedianPercent)} below the typical ${usd(prices.median)}.`;
    reasonIds = ids(input.stats);
  }

  return {
    ...base,
    verdict,
    confidence,
    reason,
    reasonEvidenceIds: reasonIds,
    priceAssessment,
    discount,
    forecast,
    retailers,
    competitors: competitorList,
    recommendation: { reasoning: `${reason} ${discount.explanation}`, evidenceIds: [...new Set([...reasonIds, ...discount.evidenceIds])] },
  };
}
