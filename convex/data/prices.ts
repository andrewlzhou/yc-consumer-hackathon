import { v } from "convex/values";
import { internalMutation, internalQuery, type QueryCtx } from "../_generated/server";
import type { Id } from "../_generated/dataModel";
import { observationSourceValidator } from "../lib/contract";
import { normalizeRetailer } from "./retailers";
import { DAY, findClaimedDiscounts, findSaleEpisodes, median, priced, round2, summarize, trustedPoints, wasPriceCheck, type PricePoint } from "./stats";

const MAX_POINTS = 3000;
const MAX_WINDOW_DAYS = 400;

// Bounded read of one product's observations, optionally one retailer, oldest first.
export async function loadWindow(
  ctx: QueryCtx,
  productId: Id<"products">,
  retailerSlug: string | undefined,
  from: number,
  to: number,
  limit = MAX_POINTS,
) {
  const query = retailerSlug
    ? ctx.db
        .query("priceObservations")
        .withIndex("by_product_and_retailerSlug_and_observedAt", (q) =>
          q.eq("productId", productId).eq("retailerSlug", retailerSlug).gte("observedAt", from).lte("observedAt", to),
        )
    : ctx.db
        .query("priceObservations")
        .withIndex("by_product_and_observedAt", (q) =>
          q.eq("productId", productId).gte("observedAt", from).lte("observedAt", to),
        );
  const newestFirst = await query.order("desc").take(Math.min(limit, MAX_POINTS) + 1);
  const truncated = newestFirst.length > Math.min(limit, MAX_POINTS);
  const rows = newestFirst.slice(0, Math.min(limit, MAX_POINTS)).reverse();
  return { rows, truncated };
}

const windowArgs = {
  productId: v.id("products"),
  now: v.number(),
  windowDays: v.optional(v.number()),
  retailerSlug: v.optional(v.string()),
};

function windowBounds(now: number, windowDays: number | undefined) {
  const days = Math.min(Math.max(windowDays ?? 180, 1), MAX_WINDOW_DAYS);
  return { from: now - days * DAY, to: now, days };
}

const toPoint = (r: { retailerSlug: string; price?: number; originalPrice?: number; inStock: boolean; observedAt: number; source: string; provider?: string; deviceId?: string }): PricePoint => ({
  provider: r.provider,
  deviceId: r.deviceId,
  retailerSlug: r.retailerSlug,
  price: r.price,
  originalPrice: r.originalPrice,
  inStock: r.inStock,
  observedAt: r.observedAt,
  source: r.source,
});

export const getPriceHistory = internalQuery({
  args: {
    productId: v.id("products"),
    retailerSlug: v.optional(v.string()),
    from: v.number(),
    to: v.number(),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const { rows, truncated } = await loadWindow(ctx, args.productId, args.retailerSlug, args.from, args.to, args.limit ?? 500);
    return { points: rows.map((r) => ({ ...toPoint(r), url: r.url })), truncated };
  },
});

// Exact stats over a window, overall and per retailer. now is passed in: queries must not read the clock.
export async function computeStats(
  ctx: QueryCtx,
  args: { productId: Id<"products">; now: number; windowDays?: number; retailerSlug?: string; currentPrice?: number; originalPrice?: number },
) {
  const { from, to, days } = windowBounds(args.now, args.windowDays);
  const { rows, truncated } = await loadWindow(ctx, args.productId, args.retailerSlug, from, to);
  const all = rows.map(toPoint);
  const points = trustedPoints(all);
  const retailers = [...new Set(points.map((p) => p.retailerSlug))].sort();
  return {
    window: { from, to, days, truncated, excludedScans: all.length - points.length },
    isSampleData: points.some((p) => p.source === "seed"),
    overall: summarize(points, args.currentPrice),
    perRetailer: retailers.map((retailerSlug) => ({
      retailerSlug,
      ...summarize(points.filter((p) => p.retailerSlug === retailerSlug), args.currentPrice),
    })),
    wasPrice: args.originalPrice === undefined ? null : wasPriceCheck(points, args.originalPrice, args.currentPrice),
  };
}

export const getPriceStats = internalQuery({
  args: { ...windowArgs, currentPrice: v.optional(v.number()), originalPrice: v.optional(v.number()) },
  handler: (ctx, args) => computeStats(ctx, args),
});

const UPCOMING_DAYS = 45;
const BASELINE_LOOKBACK = 90 * DAY;
const EVENT_MATCH_SLACK = 3 * DAY;

// Past sale episodes matched to the sale calendar, recurrence, pre-sale hikes, and upcoming events
// with how deep this product went at the same event last time.
export async function computePromo(
  ctx: QueryCtx,
  args: { productId: Id<"products">; now: number; windowDays?: number; retailerSlug?: string },
) {
  const { from, to, days } = windowBounds(args.now, args.windowDays ?? 365);
  const { rows } = await loadWindow(ctx, args.productId, args.retailerSlug, from - BASELINE_LOOKBACK, to);
  const withLookback = trustedPoints(rows.map(toPoint));
  const points = withLookback.filter((p) => p.observedAt >= from);
  const retailersSeen = new Set(points.map((p) => p.retailerSlug));
  const events = await ctx.db
    .query("saleEvents")
    .withIndex("by_startsAt", (q) => q.gte("startsAt", from - 30 * DAY).lte("startsAt", to + UPCOMING_DAYS * DAY))
    .take(200);
  const relevant = (retailerSlug: string) =>
    events.filter((e) => e.retailerSlug === undefined || e.retailerSlug === retailerSlug);

  const episodes = findSaleEpisodes(withLookback).filter((ep) => ep.startAt >= from).map((ep) => {
    const matched = relevant(ep.retailerSlug).filter(
      (e) => e.startsAt - EVENT_MATCH_SLACK <= ep.endAt && e.endsAt + EVENT_MATCH_SLACK >= ep.startAt,
    );
    return { ...ep, events: matched.map((e) => ({ name: e.name, series: e.series })) };
  });

  const starts = [...new Set(episodes.map((e) => e.startAt))].sort((a, b) => a - b);
  const gaps = starts.slice(1).map((s, i) => (s - starts[i]) / DAY);
  const seriesWithSales = [...new Set(episodes.flatMap((e) => e.events.map((x) => x.series)))].sort();

  const upcoming = events
    .filter((e) => e.endsAt >= args.now && e.startsAt <= args.now + UPCOMING_DAYS * DAY)
    .filter((e) => e.retailerSlug === undefined || retailersSeen.has(e.retailerSlug))
    .filter((e) => !args.retailerSlug || e.retailerSlug === undefined || e.retailerSlug === args.retailerSlug)
    .map((e) => {
      const past = episodes.filter((ep) => ep.events.some((x) => x.series === e.series) && ep.endAt < e.startsAt - 30 * DAY);
      return {
        name: e.name,
        series: e.series,
        retailerSlug: e.retailerSlug ?? null,
        startsAt: e.startsAt,
        endsAt: e.endsAt,
        daysAway: Math.max(0, Math.round((e.startsAt - args.now) / DAY)),
        ongoing: e.startsAt <= args.now,
        dateConfidence: e.dateConfidence,
        pastSales: past.map((ep) => ({
          retailerSlug: ep.retailerSlug,
          startAt: ep.startAt,
          minPrice: ep.minPrice,
          depthPct: ep.depthPct,
        })),
      };
    });

  const inStock = priced(points);
  return {
    window: { from, to, days },
    isSampleData: points.some((p) => p.source === "seed"),
    observationCount: inStock.length,
    typicalPrice: inStock.length ? round2(median(inStock.map((p) => p.price))) : null,
    episodes,
    recurrence: {
      episodeCount: episodes.length,
      medianGapDays: gaps.length ? Math.round(median(gaps)) : null,
      seriesWithSales,
    },
    preSaleHikes: episodes.filter((e) => e.preSaleHike).length,
    claimedDiscounts: findClaimedDiscounts(withLookback).filter((c) => c.endAt >= from),
    upcoming,
  };
}

export const findPromoPatterns = internalQuery({
  args: windowArgs,
  handler: (ctx, args) => computePromo(ctx, args),
});

const MIN_PRICE = 0.5;
const MAX_PRICE = 50_000;
const SCAN_LOW = 0.4;
const SCAN_HIGH = 2.5;
const OUTLIER_LOW = 0.25;
const OUTLIER_HIGH = 4;
const DEDUPE_WINDOW = 6 * 60 * 60 * 1000;

// Every scan, API refresh, and seed writes through here. Bad points are dropped, out-of-stock is stored
// without a price, and a repeat of the same price from the same source within 6 hours is skipped.
export const recordObservation = internalMutation({
  args: {
    productId: v.id("products"),
    retailer: v.string(),
    price: v.optional(v.number()),
    originalPrice: v.optional(v.number()),
    inStock: v.optional(v.boolean()),
    observedAt: v.optional(v.number()),
    source: observationSourceValidator,
    provider: v.optional(v.string()),
    url: v.optional(v.string()),
    deviceId: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const retailerSlug = normalizeRetailer(args.retailer);
    if (!retailerSlug) return { status: "rejected" as const, reason: "unknown retailer" };
    if (!(await ctx.db.get(args.productId))) return { status: "rejected" as const, reason: "unknown product" };
    const observedAt = args.observedAt ?? Date.now();
    if (observedAt > Date.now() + DAY) return { status: "rejected" as const, reason: "observedAt is in the future" };
    const inStock = args.inStock ?? args.price !== undefined;
    let price = inStock ? args.price : undefined;
    if (inStock && (price === undefined || !Number.isFinite(price) || price < MIN_PRICE || price > MAX_PRICE)) {
      return { status: "rejected" as const, reason: "missing or implausible price" };
    }
    if (price !== undefined) {
      price = round2(price);
      // The reference is the product's last few trusted prices at any retailer, so thin per-retailer history
      // can't be used to slip a fake price through. Scans get tighter bounds than api and scrape data.
      const { rows: productRows } = await loadWindow(ctx, args.productId, undefined, observedAt - 365 * DAY, observedAt, 200);
      const reference = priced(trustedPoints(productRows.map(toPoint))).slice(-5).map((p) => p.price);
      if (reference.length > 0) {
        const typical = median(reference);
        const [low, high] = args.source === "scan" ? [SCAN_LOW, SCAN_HIGH] : [OUTLIER_LOW, OUTLIER_HIGH];
        if (price < typical * low || price > typical * high) {
          return { status: "rejected" as const, reason: `price ${price} is far from the recent typical ${round2(typical)}` };
        }
      }
      const { rows } = await loadWindow(ctx, args.productId, retailerSlug, observedAt - DEDUPE_WINDOW, observedAt, 20);
      const last = rows[rows.length - 1];
      if (last && last.source === args.source && last.price === price && observedAt - last.observedAt < DEDUPE_WINDOW && observedAt >= last.observedAt) {
        return { status: "duplicate" as const, observationId: last._id };
      }
    }
    const originalPrice =
      price !== undefined && args.originalPrice !== undefined && Number.isFinite(args.originalPrice) && args.originalPrice > price
        ? round2(args.originalPrice)
        : undefined;
    const observationId = await ctx.db.insert("priceObservations", {
      productId: args.productId,
      retailerSlug,
      price,
      originalPrice,
      inStock,
      observedAt,
      source: args.source,
      provider: args.provider,
      url: args.url,
      deviceId: args.deviceId,
    });
    return { status: "recorded" as const, observationId, retailerSlug };
  },
});

const MAX_BATCH = 500;

// Bulk write for provider history (Keepa, price insights). Same sanity rules as recordObservation, and
// idempotent: a point from the same provider and retailer on the same UTC day is not written twice.
export const recordBatch = internalMutation({
  args: {
    productId: v.id("products"),
    retailer: v.string(),
    source: observationSourceValidator,
    provider: v.string(),
    points: v.array(
      v.object({
        price: v.optional(v.number()),
        originalPrice: v.optional(v.number()),
        inStock: v.boolean(),
        observedAt: v.number(),
        url: v.optional(v.string()),
      }),
    ),
  },
  handler: async (ctx, args) => {
    const retailerSlug = normalizeRetailer(args.retailer);
    if (!retailerSlug) return { recorded: 0, skipped: args.points.length, reason: "unknown retailer" };
    if (args.points.length > MAX_BATCH) throw new Error(`batch too large: ${args.points.length} > ${MAX_BATCH}`);
    if (!(await ctx.db.get(args.productId))) return { recorded: 0, skipped: args.points.length, reason: "unknown product" };
    if (args.points.length === 0) return { recorded: 0, skipped: 0 };
    const times = args.points.map((p) => p.observedAt);
    const { rows } = await loadWindow(ctx, args.productId, retailerSlug, Math.min(...times) - DAY, Math.max(...times) + DAY);
    const dayKey = (t: number) => Math.floor(t / DAY);
    const seen = new Set(rows.filter((r) => r.provider === args.provider).map((r) => dayKey(r.observedAt)));
    let recorded = 0;
    for (const p of args.points) {
      const priceOk = p.price !== undefined && Number.isFinite(p.price) && p.price >= MIN_PRICE && p.price <= MAX_PRICE;
      if ((p.inStock && !priceOk) || seen.has(dayKey(p.observedAt)) || p.observedAt > Date.now() + DAY) continue;
      seen.add(dayKey(p.observedAt));
      const price = p.inStock ? round2(p.price!) : undefined;
      await ctx.db.insert("priceObservations", {
        productId: args.productId,
        retailerSlug,
        price,
        originalPrice: price !== undefined && p.originalPrice !== undefined && p.originalPrice > price ? round2(p.originalPrice) : undefined,
        inStock: p.inStock,
        observedAt: p.observedAt,
        source: args.source,
        provider: args.provider,
        url: p.url,
      });
      recorded++;
    }
    return { recorded, skipped: args.points.length - recorded };
  },
});
