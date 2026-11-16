import { v } from "convex/values";
import { internal } from "../_generated/api";
import type { Id } from "../_generated/dataModel";
import { internalAction, internalMutation, internalQuery } from "../_generated/server";
import { normalizeRetailer } from "../data/retailers";
import { parseUrl } from "../data/sources/stores/url";
import { decideMatch } from "./identify";
import { rateLimiter } from "./limits";

const RETRY_PENDING_MS = 5 * 60_000;

type Resolved = { productId?: Id<"products">; title?: string; retailer?: string; currentPrice?: number; originalPrice?: number } | null;

// The store-page resolver owned by the stores thread (YCCO-8). Referenced by name so this code deploys before it
// lands; a missing or failing resolver falls back to the extract's own fields.

// Host plus path, lowercased host, no query, fragment, or trailing slash, so tracking parameters share one row.
export function normalizeUrl(raw: string): string | null {
  try {
    const u = new URL(raw);
    if (u.protocol !== "https:" && u.protocol !== "http:") return null;
    for (const k of [...u.searchParams.keys()]) if (/^(utm_.+|athbdg|gclid|fbclid|ref|ref_|tag)$/i.test(k)) u.searchParams.delete(k);
    u.searchParams.sort();
    const query = u.searchParams.toString();
    return `${u.hostname.toLowerCase().replace(/^www\./, "")}${u.pathname.replace(/\/+$/, "")}${query ? `?${query}` : ""}`;
  } catch {
    return null;
  }
}

// Amazon app shares are short links (a.co/d/..., amzn.to/...). Only these hosts are expanded, and only into Amazon.
const SHORT_HOSTS = new Set(["a.co", "amzn.to", "amzn.com", "www.amzn.com"]);
const AMAZON_HOSTS = new Set(["amazon.com", "www.amazon.com"]);
const SHORT_LINK_HOPS = 3;
const SHORT_LINK_TIMEOUT_MS = 5000;

function safeUrl(raw: string, base?: string): URL | null {
  try {
    const u = new URL(raw, base);
    return /^https?:$/.test(u.protocol) && !u.username && !u.password && !u.port ? u : null;
  } catch {
    return null;
  }
}

export function isAmazonShortLink(raw: string): boolean {
  const u = safeUrl(raw);
  return !!u && SHORT_HOSTS.has(u.hostname.toLowerCase()) && /^\/(?:d\/)?[A-Za-z0-9]{4,20}\/?$/.test(u.pathname);
}

// Follows at most three redirects without reading any page, each to an Amazon short-link or amazon.com host over
// https, and returns the canonical amazon.com/dp/ASIN link it lands on. Any other host, status, or path gives null,
// so a short link can never point this server at an arbitrary site.
export async function expandShortLink(raw: string, fetchFn: typeof fetch = fetch): Promise<string | null> {
  let url = safeUrl(raw);
  for (let hop = 0; url && hop <= SHORT_LINK_HOPS; hop++) {
    const host = url.hostname.toLowerCase();
    if (AMAZON_HOSTS.has(host)) {
      const parsed = parseUrl(url.toString());
      return parsed?.retailer === "amazon" && parsed.productCode ? parsed.url : null;
    }
    if (!SHORT_HOSTS.has(host) || hop === SHORT_LINK_HOPS) return null;
    url.protocol = "https:";
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), SHORT_LINK_TIMEOUT_MS);
    try {
      const res = await fetchFn(url.toString(), { redirect: "manual", signal: ctl.signal });
      const location = res.status >= 300 && res.status < 400 ? res.headers.get("location") : null;
      url = location ? safeUrl(location, url.toString()) : null;
    } catch {
      return null;
    } finally {
      clearTimeout(timer);
    }
  }
  return null;
}

export const lookup = internalQuery({
  args: { url: v.string(), now: v.optional(v.number()) },
  handler: async (ctx, { url, now }) => {
    const key = normalizeUrl(url);
    if (!key) return null;
    const row = await ctx.db.query("resolvedUrls").withIndex("by_url", (q) => q.eq("url", key)).first();
    if (row && now !== undefined && row.status !== "resolved" && now - row.resolvedAt >= RETRY_PENDING_MS) return null;
    return row && { status: row.status, productId: row.productId ?? null, resolvedAt: row.resolvedAt };
  },
});

// Claims a link for resolution: false when it is resolved, failed for good, or already being resolved.
export const claim = internalMutation({
  args: { url: v.string(), now: v.number() },
  handler: async (ctx, { url, now }) => {
    const row = await ctx.db.query("resolvedUrls").withIndex("by_url", (q) => q.eq("url", url)).first();
    if (row && (row.status === "resolved" || now - row.resolvedAt < RETRY_PENDING_MS)) return false;
    if (row) await ctx.db.patch(row._id, { status: "pending", resolvedAt: now, error: undefined });
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
    const url = isAmazonShortLink(args.url) ? await expandShortLink(args.url) : args.url;
    const parsed = url ? parseUrl(url) : null;
    const asin = parsed?.retailer === "amazon" ? parsed.productCode : undefined;
    const byAsin = asin ? await ctx.runQuery(internal.data.catalog.productByAsin, { asin: asin.toUpperCase() }) : null;
    if (!url) error = "short link did not lead to an Amazon product";
    else if (!byAsin)
      try {
        resolved = await ctx.runAction(internal.data.sources.stores.resolve.resolveUrl, { url, title: args.title, retailer: args.retailer });
      } catch (e) {
        error = `resolver: ${String(e).slice(0, 200)}`;
      }
    const title = resolved?.title ?? args.title;
    let productId = byAsin?._id ?? resolved?.productId;
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
      retailer: normalizeRetailer(resolved?.retailer ?? args.retailer ?? parsed?.retailer) ?? "unknown",
      currentPrice: resolved?.currentPrice ?? args.currentPrice ?? null,
      originalPrice: resolved?.originalPrice ?? args.originalPrice ?? null,
    };
    const jobId = await ctx.runMutation(internal.agent.store.claimJob, { productId, now: Date.now() });
    if (jobId) await ctx.scheduler.runAfter(0, internal.agent.analyze.runFullAnalysis, { productId, jobId, scan, now: args.now });
    return productId;
  },
});
