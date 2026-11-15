// The only file that knows how to reach the data layer and the shopping agent. Rewire here when their APIs change.
import { v } from "convex/values";
import { internal } from "../_generated/api";
import { internalAction, internalQuery } from "../_generated/server";
import { loadWindow, computePromo } from "../data/prices";
import { DAY, median, priced } from "../data/stats";
import type { Snapshot } from "./policy";

export type ProductSnapshot = { title: string; snapshot: Snapshot };

const money = (n: number) => "$" + n.toFixed(2);

// Builds a snapshot from stored price history: the cheapest latest in-stock price across retailers, the lowest
// price seen before it, and whether a calendar sale is running. Verdict and reason are placeholders until the
// shopping agent's analysis is wired in (see getSnapshot); verdict is INVESTIGATE so no verdict trigger fires.
export const readState = internalQuery({
  args: { productId: v.id("products"), now: v.number() },
  handler: async (ctx, args): Promise<ProductSnapshot | null> => {
    const product = await ctx.db.get(args.productId);
    if (!product) return null;
    const { rows } = await loadWindow(ctx, args.productId, undefined, args.now - 365 * DAY, args.now);
    const inStock = priced(rows);
    if (inStock.length === 0) return null;
    const latestPerRetailer = new Map<string, (typeof inStock)[number]>();
    for (const r of inStock) {
      const seen = latestPerRetailer.get(r.retailerSlug);
      if (!seen || r.observedAt >= seen.observedAt) latestPerRetailer.set(r.retailerSlug, r);
    }
    const current = [...latestPerRetailer.values()].sort((a, b) => a.price - b.price || b.observedAt - a.observedAt)[0];
    const history = inStock.filter((r) => r !== current);
    const priorLow = history.length ? Math.min(...history.map((r) => r.price)) : undefined;
    const promo = await computePromo(ctx, { productId: args.productId, now: args.now });
    const typical = history.length ? median(history.map((r) => r.price)) : undefined;
    const saleStartDetected =
      typical !== undefined &&
      current.price < typical * 0.95 &&
      promo.upcoming.some((e) => e.ongoing && (e.retailerSlug === null || e.retailerSlug === current.retailerSlug));
    const reason =
      priorLow !== undefined
        ? money(current.price) + " at " + current.retailerSlug + "; previous lowest seen was " + money(priorLow) + " over " + history.length + " earlier observations."
        : money(current.price) + " at " + current.retailerSlug + "; too little history to compare.";
    return {
      title: product.title,
      snapshot: {
        currentPrice: current.price,
        priceSource: current.source as Snapshot["priceSource"],
        priorLow,
        verdict: "INVESTIGATE",
        confidence: 0,
        reason,
        saleStartDetected,
      },
    };
  },
});

// Refreshes prices for a product and re-runs the analysis, returning what monitoring needs.
// Not wired yet: the data layer has no live price source and the agent's analysis action has not landed on this
// branch, so this reads the latest stored observation. Replace the verdict, confidence, reason, alternative and
// the sale flag here with the agent's output once it exists.
export const getSnapshot = internalAction({
  args: { productId: v.id("products") },
  handler: async (ctx, args): Promise<ProductSnapshot> => {
    const state: ProductSnapshot | null = await ctx.runQuery(internal.monitoring.ports.readState, { productId: args.productId, now: Date.now() });
    if (!state) throw new Error("no price history for this product");
    return state;
  },
});
