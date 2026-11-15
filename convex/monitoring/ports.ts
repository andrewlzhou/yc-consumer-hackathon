// The only file that knows how to reach the data layer and the shopping agent. Rewire here when their APIs change.
import { v } from "convex/values";
import { internal } from "../_generated/api";
import { internalAction, internalQuery } from "../_generated/server";
import { analysisForMonitoring } from "../agent/monitor";
import { computePromo, loadWindow } from "../data/prices";
import { DAY, median, trustedPoints } from "../data/stats";
import type { Snapshot } from "./policy";

export type ProductSnapshot = { title: string; snapshot: Snapshot };
type State = ProductSnapshot & { retailerSlug: string };

const HOUR = 3_600_000;
const MAX_AGE: Record<string, number> = { api: 72 * HOUR, scrape: 72 * HOUR, scan: 24 * HOUR };
const REFRESH_MIN_AGE = 6 * HOUR;

const money = (n: number) => "$" + n.toFixed(2);

// Price facts from stored history, after dropping scans nothing corroborates (data/stats trustedPoints). The current
// price is the cheapest fresh in-stock latest row per retailer, taken from real (non-seed) rows when any exist. The previous low and typical price use real rows only, so seeded
// history never becomes a stated fact. Seed rows in the window mark the verdict as sample-derived. Returns null
// when no price is fresh enough to call current.
export const readState = internalQuery({
  args: { productId: v.id("products"), now: v.number() },
  handler: async (ctx, args): Promise<(State & { hasSeedRows: boolean }) | null> => {
    const product = await ctx.db.get(args.productId);
    if (!product) return null;
    const rows = trustedPoints((await loadWindow(ctx, args.productId, undefined, args.now - 365 * DAY, args.now)).rows);
    const hasSeedRows = rows.some((r) => r.source === "seed");
    const latestPerRetailer = new Map<string, (typeof rows)[number]>();
    for (const r of rows) {
      const seen = latestPerRetailer.get(r.retailerSlug);
      if (!seen || r.observedAt >= seen.observedAt) latestPerRetailer.set(r.retailerSlug, r);
    }
    const fresh = [...latestPerRetailer.values()].filter(
      (r) => r.inStock && typeof r.price === "number" && (r.source === "seed" || args.now - r.observedAt <= (MAX_AGE[r.source] ?? 24 * HOUR)),
    );
    const real = fresh.filter((r) => r.source !== "seed");
    const pool = real.length ? real : fresh;
    const current = pool.sort((a, b) => a.price! - b.price! || b.observedAt - a.observedAt)[0];
    if (!current) return null;
    const currentPrice = current.price!;
    const history = rows.filter((r) => r !== current && r.source !== "seed" && r.inStock && typeof r.price === "number");
    const priorLow = history.length ? Math.min(...history.map((r) => r.price!)) : undefined;
    const typical = history.length ? median(history.map((r) => r.price!)) : undefined;
    const promo = await computePromo(ctx, { productId: args.productId, now: args.now });
    const saleStartDetected =
      typical !== undefined &&
      currentPrice < typical * 0.95 &&
      promo.upcoming.some((e) => e.ongoing && (e.retailerSlug === null || e.retailerSlug === current.retailerSlug));
    const reason =
      priorLow !== undefined
        ? money(currentPrice) + " at " + current.retailerSlug + "; previous lowest seen was " + money(priorLow) + " over " + history.length + " earlier observations."
        : money(currentPrice) + " at " + current.retailerSlug + "; too little history to compare.";
    return {
      title: product.title,
      retailerSlug: current.retailerSlug,
      hasSeedRows,
      snapshot: {
        currentPrice,
        priceSource: current.source as Snapshot["priceSource"],
        priorLow,
        verdict: "INVESTIGATE",
        confidence: 0,
        reason,
        saleStartDetected,
        isSampleData: hasSeedRows,
      },
    };
  },
});

const lastRealObservation = internalQuery({
  args: { productId: v.id("products") },
  handler: async (ctx, args) => {
    const rows = await ctx.db
      .query("priceObservations")
      .withIndex("by_product_and_observedAt", (q) => q.eq("productId", args.productId))
      .order("desc")
      .take(50);
    return rows.find((r) => r.source !== "seed")?.observedAt ?? null;
  },
});
export { lastRealObservation };

// Pulls fresh real prices (SerpApi Google Shopping/Product, source "api") when the newest real observation is
// older than 6 hours. Costs search credits, so the sweep caps how many products it asks for.
export const refreshPrices = internalAction({
  args: { productId: v.id("products") },
  handler: async (ctx, args): Promise<{ status: string }> => {
    const last: number | null = await ctx.runQuery(internal.monitoring.ports.lastRealObservation, { productId: args.productId });
    if (last !== null && Date.now() - last < REFRESH_MIN_AGE) return { status: "fresh_enough" };
    try {
      const res = await ctx.runAction(internal.data.sources.serpapi.refreshCurrentPrices, { productId: args.productId });
      return { status: res.status };
    } catch {
      return { status: "refresh_failed" };
    }
  },
});

// Stored price history gives the price facts; the shopping agent's newest analysis gives verdict, confidence,
// reason and alternative (and queues a background re-analysis when stale). Without a usable analysis the
// placeholder INVESTIGATE stays, so no verdict trigger fires. Returns null when there is no fresh current price.
export const getSnapshot = internalAction({
  args: { productId: v.id("products") },
  handler: async (ctx, args): Promise<ProductSnapshot | null> => {
    const now = Date.now();
    const state: (State & { hasSeedRows: boolean }) | null = await ctx.runQuery(internal.monitoring.ports.readState, { productId: args.productId, now });
    if (!state) return null;
    const analysis = await analysisForMonitoring(
      ctx,
      args.productId,
      state.snapshot.currentPrice,
      state.retailerSlug,
      now,
    );
    if (!analysis) return { title: state.title, snapshot: state.snapshot };
    const { isSampleData, ...verdictFields } = analysis;
    return { title: state.title, snapshot: { ...state.snapshot, ...verdictFields, isSampleData: state.hasSeedRows || isSampleData === true } };
  },
});
