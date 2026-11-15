import { v } from "convex/values";
import { internal } from "../../_generated/api";
import type { Doc, Id } from "../../_generated/dataModel";
import { internalAction, internalMutation, internalQuery, type ActionCtx } from "../../_generated/server";
import { scoreCandidate } from "../catalog";
import { KNOWN_RETAILERS } from "../retailers";
import { tokenize } from "../text";

// SerpApi Google Shopping + Google Product: current prices across retailers, and Google's own per-store
// price history (product_results.price_insights). Needs SERPAPI_API_KEY. Shapes follow the documented
// responses at https://serpapi.com/google-shopping-api and https://serpapi.com/google-product-api;
// the live shape is unverified until a key exists.

export type Offer = { retailerSlug: string; price: number; originalPrice?: number; url?: string; title: string };
export type HistoryPoint = { retailerSlug: string; price: number; observedAt: number };

type ShoppingResult = {
  title?: string;
  source?: string;
  product_id?: string;
  immersive_product_page_token?: string;
  extracted_price?: number;
  extracted_old_price?: number;
  product_link?: string;
  link?: string;
  second_hand_condition?: string;
};

type Store = {
  name?: string;
  title?: string;
  link?: string;
  extracted_price?: number;
  extracted_original_price?: number;
  details_and_offers?: string[];
};

type GoogleProduct = {
  title?: string;
  brand?: string;
  stores?: Store[];
  about_the_product?: { features?: { title?: string; value?: string }[] };
  price_insights?: { currency?: string; stores?: { name?: string; prices?: { date?: string; price?: number }[] }[] };
};

const NOT_THE_PRODUCT = /\b(refurbished|renewed|pre-owned|used|case|cover|replacement|skin|protector|charger only)\b/i;
const MIN_TITLE_SCORE = 0.6;
export const SERPAPI_PROVIDERS = {
  shopping: "serpapi-google-shopping",
  product: "serpapi-google-product",
  history: "serpapi-google-price-history",
};

// "Walmart", "Best Buy", "Amazon.com" are the retailer itself; "Walmart - SellerName" is a marketplace seller, skipped.
export function retailerFromSource(source: string | undefined): string | null {
  if (!source || source.includes(" - ")) return null;
  const s = source.toLowerCase().replace(/\.com$/, "").trim();
  return KNOWN_RETAILERS.find((r) => r.aliases.includes(s) || r.slug === s.replace(/\s+/g, ""))?.slug ?? null;
}

const isSameProduct = (title: string | undefined, product: Doc<"products">) => {
  if (!title || NOT_THE_PRODUCT.test(title)) return false;
  const m = scoreCandidate(tokenize(title), product);
  return !m.sizeConflict && m.score >= MIN_TITLE_SCORE;
};

// First matching offer per known retailer; accessories, used items, and other variants are dropped.
export function parseShoppingResults(json: unknown, product: Doc<"products">): Offer[] {
  const results = (json as { shopping_results?: ShoppingResult[] })?.shopping_results ?? [];
  const offers = new Map<string, Offer>();
  for (const r of results) {
    const retailerSlug = retailerFromSource(r.source);
    if (!retailerSlug || offers.has(retailerSlug) || r.second_hand_condition) continue;
    if (typeof r.extracted_price !== "number" || !isSameProduct(r.title, product)) continue;
    offers.set(retailerSlug, {
      retailerSlug,
      price: r.extracted_price,
      originalPrice: typeof r.extracted_old_price === "number" ? r.extracted_old_price : undefined,
      url: r.product_link ?? r.link,
      title: r.title!,
    });
  }
  return [...offers.values()];
}

// The shopping result that best matches a title, for finding Google's product id.
export function bestShoppingResult(json: unknown, title: string) {
  const results = (json as { shopping_results?: ShoppingResult[] })?.shopping_results ?? [];
  const queryTokens = tokenize(title);
  let best: { result: ShoppingResult; score: number } | null = null;
  for (const r of results) {
    if (!r.title || !r.product_id || NOT_THE_PRODUCT.test(r.title) || r.second_hand_condition) continue;
    const resultTokens = new Set(tokenize(r.title));
    const score = queryTokens.filter((t) => resultTokens.has(t)).length / Math.max(queryTokens.length, 1);
    if (!best || score > best.score) best = { result: r, score };
  }
  return best && best.score >= 0.5 ? { ...best.result, score: Math.round(best.score * 1000) / 1000 } : null;
}

// "May 30, 2026" -> 17:00 UTC that day, matching how other daily points are timestamped.
export function parseInsightDate(s: string | undefined): number | null {
  if (!s) return null;
  const t = Date.parse(s + " 17:00 UTC");
  return Number.isFinite(t) ? t : null;
}

export function parseGoogleProduct(json: unknown, product: Doc<"products"> | null) {
  const p = ((json as { product_results?: GoogleProduct })?.product_results ?? {}) as GoogleProduct;
  const offers = new Map<string, Offer>();
  for (const s of p.stores ?? []) {
    const retailerSlug = retailerFromSource(s.name);
    if (!retailerSlug || offers.has(retailerSlug) || typeof s.extracted_price !== "number") continue;
    if (product && s.title && !isSameProduct(s.title, product)) continue;
    offers.set(retailerSlug, {
      retailerSlug,
      price: s.extracted_price,
      originalPrice: typeof s.extracted_original_price === "number" ? s.extracted_original_price : undefined,
      url: s.link,
      title: s.title ?? p.title ?? "",
    });
  }
  const history: HistoryPoint[] = [];
  if ((p.price_insights?.currency ?? "USD") === "USD") {
    for (const s of p.price_insights?.stores ?? []) {
      const retailerSlug = retailerFromSource(s.name);
      if (!retailerSlug) continue;
      for (const point of s.prices ?? []) {
        const observedAt = parseInsightDate(point.date);
        if (observedAt !== null && typeof point.price === "number") history.push({ retailerSlug, price: point.price, observedAt });
      }
    }
  }
  const specs: Record<string, string> = {};
  for (const f of p.about_the_product?.features ?? []) {
    if (f.title && f.value) specs[f.title.replace(/[^A-Za-z0-9 ]/g, "").trim().replace(/\s+(.)/g, (_, c) => c.toUpperCase()).replace(/^./, (c) => c.toLowerCase())] = f.value;
  }
  return { title: p.title ?? null, brand: p.brand ?? null, offers: [...offers.values()], history, specs };
}

const DAY = 24 * 60 * 60 * 1000;

// Google lists a store's price only on the days it changed. Each change becomes one point per day until the next
// change (the last one runs to the newest date in the response), so medians and day shares are time-weighted.
export function dailySteps(history: HistoryPoint[]): HistoryPoint[] {
  if (history.length === 0) return [];
  const until = Math.max(...history.map((h) => h.observedAt));
  const out: HistoryPoint[] = [];
  for (const retailerSlug of new Set(history.map((h) => h.retailerSlug))) {
    const changes = history.filter((h) => h.retailerSlug === retailerSlug).sort((a, b) => a.observedAt - b.observedAt);
    changes.forEach((c, i) => {
      const end = i + 1 < changes.length ? changes[i + 1].observedAt : until + DAY;
      for (let t = c.observedAt; t < end; t += DAY) out.push({ retailerSlug, price: c.price, observedAt: t });
    });
  }
  return out;
}

async function serpapi(params: Record<string, string>) {
  const key = process.env.SERPAPI_API_KEY;
  if (!key) return { status: "no_key" as const };
  const url = new URL("https://serpapi.com/search.json");
  for (const [k, val] of Object.entries({ gl: "us", hl: "en", ...params, api_key: key })) url.searchParams.set(k, val);
  const started = Date.now();
  const res = await fetch(url);
  const latencyMs = Date.now() - started;
  if (!res.ok) return { status: "error" as const, httpStatus: res.status, latencyMs };
  return { status: "ok" as const, json: (await res.json()) as unknown, latencyMs };
}

export const productForRefresh = internalQuery({
  args: { productId: v.id("products") },
  handler: (ctx, args) => ctx.db.get(args.productId),
});

export const setGoogleProductId = internalMutation({
  args: { productId: v.id("products"), googleProductId: v.string() },
  handler: async (ctx, args) => {
    const p = await ctx.db.get(args.productId);
    if (!p) return;
    await ctx.db.patch(args.productId, { identifiers: { ...p.identifiers, googleProductId: args.googleProductId } });
  },
});

async function recordOffers(ctx: ActionCtx, productId: Id<"products">, offers: Offer[], provider: string, observedAt: number) {
  let recorded = 0;
  for (const o of offers) {
    const r: { status: string } = await ctx.runMutation(internal.data.prices.recordObservation, {
      productId,
      retailer: o.retailerSlug,
      price: o.price,
      originalPrice: o.originalPrice,
      observedAt,
      source: "api",
      provider,
      url: o.url,
    });
    if (r.status === "recorded") recorded++;
  }
  return recorded;
}

async function recordHistory(ctx: ActionCtx, productId: Id<"products">, history: HistoryPoint[]) {
  let recorded = 0;
  for (const retailerSlug of new Set(history.map((h) => h.retailerSlug))) {
    const points = history
      .filter((h) => h.retailerSlug === retailerSlug)
      .map((h) => ({ price: h.price, inStock: true, observedAt: h.observedAt }));
    for (let i = 0; i < points.length; i += 500) {
      const r: { recorded: number } = await ctx.runMutation(internal.data.prices.recordBatch, {
        productId,
        retailer: retailerSlug,
        source: "api",
        provider: SERPAPI_PROVIDERS.history,
        points: points.slice(i, i + 500),
      });
      recorded += r.recorded;
    }
  }
  return recorded;
}

// Refresh one catalog product: find its Google product id once (1 search), then read the product page
// (1 search) for per-retailer offers and Google's price history. Writes as source "api".
export type RefreshResult =
  | { status: "no_key" | "unknown_product"; recorded: number }
  | { status: "error"; httpStatus: number; latencyMs: number; recorded: number }
  | { status: "ok"; recorded: number; offers: Offer[]; historyPoints: number; googleProductId: string | null; latencyMs: number[] };

export async function refreshProduct(ctx: ActionCtx, productId: Id<"products">): Promise<RefreshResult> {
  const product: Doc<"products"> | null = await ctx.runQuery(internal.data.sources.serpapi.productForRefresh, { productId });
  if (!product) return { status: "unknown_product" as const, recorded: 0 };
  let googleProductId = product.identifiers?.googleProductId;
  const searches: number[] = [];
  let shoppingOffers: Offer[] = [];
  if (!googleProductId) {
    const q = [product.title, product.variant?.storage].filter(Boolean).join(" ");
    const shop = await serpapi({ engine: "google_shopping", q });
    if (shop.status !== "ok") return { ...shop, recorded: 0 };
    searches.push(shop.latencyMs);
    shoppingOffers = parseShoppingResults(shop.json, product);
    const best = bestShoppingResult(shop.json, product.title);
    if (best?.product_id) {
      googleProductId = best.product_id;
      await ctx.runMutation(internal.data.sources.serpapi.setGoogleProductId, { productId, googleProductId });
    }
  }
  const observedAt = Date.now();
  if (!googleProductId) {
    const recorded = await recordOffers(ctx, productId, shoppingOffers, SERPAPI_PROVIDERS.shopping, observedAt);
    return { status: "ok" as const, recorded, offers: shoppingOffers, historyPoints: 0, googleProductId: null, latencyMs: searches };
  }
  const page = await serpapi({ engine: "google_product", product_id: googleProductId, offer_view: "true" });
  if (page.status !== "ok") return { ...page, recorded: 0 };
  searches.push(page.latencyMs);
  const parsed = parseGoogleProduct(page.json, product);
  const offers = parsed.offers.length ? parsed.offers : shoppingOffers;
  const recorded = await recordOffers(ctx, productId, offers, parsed.offers.length ? SERPAPI_PROVIDERS.product : SERPAPI_PROVIDERS.shopping, observedAt);
  const historyPoints = await recordHistory(ctx, productId, dailySteps(parsed.history));
  return { status: "ok" as const, recorded, offers, historyPoints, googleProductId, latencyMs: searches };
}

export const refreshCurrentPrices = internalAction({
  args: { productId: v.id("products") },
  handler: (ctx, args) => refreshProduct(ctx, args.productId),
});

// Search Google Shopping for a title we have never seen; returns the best match and its Google product page.
export async function lookupByTitle(title: string) {
  const shop = await serpapi({ engine: "google_shopping", q: title });
  if (shop.status !== "ok") return shop;
  const best = bestShoppingResult(shop.json, title);
  if (!best) return { status: "not_found" as const };
  const page = await serpapi({ engine: "google_product", product_id: best.product_id!, offer_view: "true" });
  if (page.status !== "ok") return page;
  return { status: "ok" as const, best, page: parseGoogleProduct(page.json, null), latencyMs: [shop.latencyMs, page.latencyMs] };
}
