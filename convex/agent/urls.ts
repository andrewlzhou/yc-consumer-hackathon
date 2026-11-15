import { makeFunctionReference } from "convex/server";
import { v } from "convex/values";
import { internal } from "../_generated/api";
import type { Id } from "../_generated/dataModel";
import { internalAction, internalMutation, internalQuery } from "../_generated/server";
import { normalizeRetailer } from "../data/retailers";
import { decideMatch } from "./identify";
import { rateLimiter } from "./limits";

const RETRY_PENDING_MS = 5 * 60_000;

type Resolved = { productId?: Id<"products">; title?: string; retailer?: string; currentPrice?: number; originalPrice?: number } | null;

// The store-page resolver owned by the stores thread (YCCO-8). Referenced by name so this code deploys before it
// lands; a missing or failing resolver falls back to the extract's own fields.
const resolveUrl = makeFunctionReference<"action", { url: string; title?: string; retailer?: string }, Resolved>("data/sources/stores/resolve:resolveUrl");

// Host plus path, lowercased host, no query, fragment, or trailing slash, so tracking parameters share one row.
export function normalizeUrl(raw: string): string | null {
  try {
    const u = new URL(raw);
    if (u.protocol !== "https:" && u.protocol !== "http:") return null;
    return `${u.hostname.toLowerCase().replace(/^www\./, "")}${u.pathname.replace(/\/+$/, "")}`;
  } catch {
    return null;
  }
}

export const lookup = internalQuery({
  args: { url: v.string() },
  handler: async (ctx, { url }) => {
    const key = normalizeUrl(url);
    if (!key) return null;
    const row = await ctx.db.query("resolvedUrls").withIndex("by_url", (q) => q.eq("url", key)).first();
    return row && { status: row.status, productId: row.productId ?? null, resolvedAt: row.resolvedAt };
  },
});

// Claims a link for resolution: false when it is resolved, failed for good, or already being resolved.
export const claim = internalMutation({
  args: { url: v.string(), now: v.number() },
  handler: async (ctx, { url, now }) => {
    const row = await ctx.db.query("resolvedUrls").withIndex("by_url", (q) => q.eq("url", url)).first();
    if (row && (row.status !== "pending" || now - row.resolvedAt < RETRY_PENDING_MS)) return false;
    if (row) await ctx.db.patch(row._id, { resolvedAt: now });
    else await ctx.db.insert("resolvedUrls", { url, status: "pending", resolvedAt: now });
    return true;
  },
});

export const settle = internalMutation({
  args: { url: v.string(), productId: v.optional(v.id("products")), error: v.optional(v.string()), now: v.number() },
  handler: async (ctx, { url, productId, error, now }) => {
    const row = await ctx.db.query("resolvedUrls").withIndex("by_url", (q) => q.eq("url", url)).first();
    const fields = { status: productId ? ("resolved" as const) : ("failed" as const), productId, error, resolvedAt: now };
    if (row) await ctx.db.patch(row._id, fields);
    else await ctx.db.insert("resolvedUrls", { url, ...fields });
    return null;
  },
});

// Resolves a product link off the live path: the store resolver first, then the extract's title. When the scan had
// no catalog match, it also starts the full analysis for the resolved product.
export const resolveInBackground = internalAction({
  args: {
    url: v.string(),
    title: v.optional(v.string()),
    retailer: v.optional(v.string()),
    deviceId: v.optional(v.string()),
    currentPrice: v.optional(v.number()),
    originalPrice: v.optional(v.number()),
    now: v.number(),
    startFullRun: v.boolean(),
  },
  handler: async (ctx, args): Promise<Id<"products"> | null> => {
    const key = normalizeUrl(args.url);
    if (!key || !(await ctx.runMutation(internal.agent.urls.claim, { url: key, now: Date.now() }))) return null;
    let resolved: Resolved = null;
    let error: string | undefined;
    try {
      resolved = await ctx.runAction(resolveUrl, { url: args.url, title: args.title, retailer: args.retailer });
    } catch (e) {
      error = `resolver: ${String(e).slice(0, 200)}`;
    }
    const title = resolved?.title ?? args.title;
    let productId = resolved?.productId;
    if (!productId && title) {
      const decision = decideMatch(await ctx.runQuery(internal.data.catalog.matchProduct, { title, limit: 6 }));
      if (decision.kind === "match") productId = decision.candidate.product._id;
      else if (args.startFullRun && (!args.deviceId || (await rateLimiter.limit(ctx, "provisionalPerDevice", { key: args.deviceId })).ok))
        productId = await ctx.runMutation(internal.data.catalog.createProvisionalProduct, { title });
    }
    await ctx.runMutation(internal.agent.urls.settle, { url: key, productId, error: productId ? undefined : (error ?? "no product found"), now: Date.now() });
    if (!productId || !args.startFullRun) return productId ?? null;
    const scan = {
      title: title ?? null,
      retailer: normalizeRetailer(resolved?.retailer ?? args.retailer) ?? "unknown",
      currentPrice: resolved?.currentPrice ?? args.currentPrice ?? null,
      originalPrice: resolved?.originalPrice ?? args.originalPrice ?? null,
    };
    const jobId = await ctx.runMutation(internal.agent.store.claimJob, { productId, now: Date.now() });
    if (jobId) await ctx.scheduler.runAfter(0, internal.agent.analyze.runFullAnalysis, { productId, jobId, scan, now: args.now });
    return productId;
  },
});
