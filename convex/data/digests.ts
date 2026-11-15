import { v } from "convex/values";
import { internalMutation, internalQuery, type MutationCtx } from "../_generated/server";
import type { Doc, Id } from "../_generated/dataModel";
import { computePromo, computeStats } from "./prices";

const DIGEST_WINDOW_DAYS = 365;
const RECENT_WINDOW_DAYS = 90;

const date = (t: number) => new Date(t).toISOString().slice(0, 10);
const money = (n: number) => "$" + n.toFixed(2);
const pct = (n: number) => Math.round(n * 100) + "%";

type Stats = Awaited<ReturnType<typeof computeStats>>;
type Promo = Awaited<ReturnType<typeof computePromo>>;

// A short paragraph the agent can read instead of raw points. Every number here comes from stats or promo.
export function buildDigestText(product: Doc<"products">, stats: Stats, recent: Stats, promo: Promo): string {
  const lines: string[] = [];
  const sample = stats.isSampleData ? "SAMPLE DATA (seeded, not real observations). " : "";
  const variant = product.variant ? " [" + Object.values(product.variant).join(", ") + "]" : "";
  lines.push(`${sample}${product.title}${variant}. Window ${date(stats.window.from)} to ${date(stats.window.to)}.`);
  const o = stats.overall;
  if (!o.prices || !o.current) {
    lines.push("No in-stock price observations in this window.");
    return lines.join("\n");
  }
  const p = o.prices;
  lines.push(
    `${o.observationCount} in-stock observations (${o.outOfStockCount} out of stock) over ${p.spanDays} days at ${stats.perRetailer.map((r) => r.retailerSlug).join(", ")}.`,
  );
  lines.push(
    `Typical (median) ${money(p.median)}, mean ${money(p.mean)}, low ${money(p.min)} (last seen ${date(p.minLastSeenAt)} at ${p.minRetailers.join(", ")}), high ${money(p.max)}.`,
  );
  lines.push(
    `Latest ${money(p.latest.price)} at ${p.latest.retailerSlug} on ${date(p.latest.observedAt)}; that is percentile ${o.current.percentile} of the window and ${pct(o.current.vsMedianPct)} vs typical.`,
  );
  if (recent.overall.prices && recent.overall.current) {
    const rp = recent.overall.prices;
    lines.push(`Last ${recent.window.days} days: typical ${money(rp.median)}, low ${money(rp.min)}, high ${money(rp.max)}; latest is percentile ${recent.overall.current.percentile} of that period.`);
  }
  for (const r of stats.perRetailer) {
    if (!r.prices) {
      lines.push(`${r.retailerSlug}: no in-stock price (${r.outOfStockCount} out-of-stock checks).`);
      continue;
    }
    lines.push(`${r.retailerSlug}: latest ${money(r.prices.latest.price)} (${date(r.prices.latest.observedAt)}), typical ${money(r.prices.median)}, low ${money(r.prices.min)}, ${r.observationCount} obs.`);
  }
  if (promo.episodes.length) {
    const parts = promo.episodes.map(
      (e) => `${e.retailerSlug} ${date(e.startAt)}${e.events.length ? " (" + e.events.map((x) => x.name).join("/") + ")" : ""} low ${money(e.minPrice)}, ${pct(e.depthPct)} under typical${e.preSaleHike ? ", after a pre-sale price hike" : ""}`,
    );
    lines.push(`Sales seen (${promo.recurrence.episodeCount}, median gap ${promo.recurrence.medianGapDays ?? "n/a"} days): ${parts.join("; ")}.`);
  } else {
    lines.push("No sale dips of 7% or more below the typical price in the window.");
  }
  const suspicious = promo.claimedDiscounts.filter((c) => c.wasRarelyCharged || c.preSaleHike);
  for (const c of suspicious) {
    lines.push(
      `Claimed discount at ${c.retailerSlug} from ${date(c.startAt)}: ${money(c.minPrice)} "was ${money(c.claimedOriginalPrice)}" (${pct(c.claimedPct)} claimed); the was-price was charged in ${pct(c.wasChargedShareBefore ?? 0)} of the prior 90 days and the real saving vs typical ${c.typicalBefore === null ? "n/a" : money(c.typicalBefore)} is ${c.realPct === null ? "n/a" : pct(c.realPct)}${c.preSaleHike ? "; price was raised " + pct(c.preSaleHikePct ?? 0) + " in the 3 weeks before" : ""}.`,
    );
  }
  for (const u of promo.upcoming.slice(0, 8)) {
    const past = u.pastSales.length
      ? "last time: " + u.pastSales.map((s) => `${s.retailerSlug} ${money(s.minPrice)} (${pct(s.depthPct)} off)`).join(", ")
      : "no matching past sale for this product";
    const when = u.ongoing ? "running now" : `in ${u.daysAway} days`;
    lines.push(`Upcoming: ${u.name} ${when} (${u.dateConfidence}); ${past}.`);
  }
  return lines.join("\n");
}

export async function refreshDigestFor(ctx: MutationCtx, productId: Id<"products">, now: number) {
  const product = await ctx.db.get(productId);
  if (!product) return null;
  const stats = await computeStats(ctx, { productId, now, windowDays: DIGEST_WINDOW_DAYS });
  const recent = await computeStats(ctx, { productId, now, windowDays: RECENT_WINDOW_DAYS });
  const promo = await computePromo(ctx, { productId, now, windowDays: DIGEST_WINDOW_DAYS });
  const doc = {
    productId,
    text: buildDigestText(product, stats, recent, promo),
    computedAt: now,
    windowStart: stats.window.from,
    windowEnd: stats.window.to,
    observationCount: stats.overall.observationCount,
    isSampleData: stats.isSampleData,
  };
  const existing = await ctx.db
    .query("priceDigests")
    .withIndex("by_productId", (q) => q.eq("productId", productId))
    .unique();
  if (existing) await ctx.db.replace(existing._id, doc);
  else await ctx.db.insert("priceDigests", doc);
  return doc;
}

export const refreshDigest = internalMutation({
  args: { productId: v.id("products"), now: v.optional(v.number()) },
  handler: (ctx, args) => refreshDigestFor(ctx, args.productId, args.now ?? Date.now()),
});

export const getDigest = internalQuery({
  args: { productId: v.id("products") },
  handler: async (ctx, args) => {
    const d = await ctx.db
      .query("priceDigests")
      .withIndex("by_productId", (q) => q.eq("productId", args.productId))
      .unique();
    return d ? { text: d.text, computedAt: d.computedAt, observationCount: d.observationCount, isSampleData: d.isSampleData } : null;
  },
});
