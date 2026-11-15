import { v } from "convex/values";
import { internal } from "../../_generated/api";
import type { Id } from "../../_generated/dataModel";
import { internalAction, internalQuery } from "../../_generated/server";
import { DAY } from "../stats";

// Amazon price history from Keepa. Needs KEEPA_API_KEY. Unverified live until a key exists; the parsers are
// tested against fixtures written from the docs: https://keepa.com/api-docs/product-object.html (csv array,
// Keepa time), https://keepa.com/api-docs/product.html (request), https://keepa.com/api-docs/product-search.html.
// Tokens: product request 1 per ASIN; the `offers` parameter replaces that with a minimum of 5 (6 per offer page);
// a search costs 10. Free of charge: history, days, stats.

const KEEPA_TIME_OFFSET_MINUTES = 21_564_000;
const AMAZON = 0;
const BUY_BOX_SHIPPING = 18;
const SAMPLE_HOUR_UTC = 17;
const HOUR = 60 * 60 * 1000;
const MAX_BATCH = 500;
const US_DOMAIN = "1";

export type KeepaProduct = {
  asin?: string;
  title?: string;
  upcList?: string[];
  eanList?: string[];
  csv?: (number[] | null)[];
};

export type KeepaPoint = { observedAt: number; price?: number; inStock: boolean };
export type KeepaSeries = "amazon" | "buybox" | "none";

// Keepa time is minutes since 2011-01-01; the docs give unix ms = (keepaTime + 21564000) * 60000.
export const keepaTimeToUnixMs = (keepaMinutes: number) => (keepaMinutes + KEEPA_TIME_OFFSET_MINUTES) * 60_000;

type Change = { at: number; price: number | null };

// csv rows are flat: [time, value, time, value] or, with shipping, [time, price, shipping, ...]. -1 means no offer.
// The buy box is stored as the landing price (price plus shipping when Keepa knows it).
function decodeChanges(row: number[] | null | undefined, step: 2 | 3): Change[] {
  const changes: Change[] = [];
  for (let i = 0; row && i + 1 < row.length; i += step) {
    const cents = row[i + 1];
    const shipping = step === 3 ? Math.max(row[i + 2] ?? 0, 0) : 0;
    changes.push({ at: keepaTimeToUnixMs(row[i]), price: cents < 0 ? null : (cents + shipping) / 100 });
  }
  return changes;
}

// One sample per UTC day: the price in effect at 17:00 UTC. Days before the first known change are skipped.
function dailySamples(changes: Change[], now: number, days: number): KeepaPoint[] {
  const lastDay = Math.floor(now / DAY);
  const points: KeepaPoint[] = [];
  let current = -1;
  for (let day = lastDay - days + 1; day <= lastDay; day++) {
    const observedAt = day * DAY + SAMPLE_HOUR_UTC * HOUR;
    if (observedAt > now) break;
    while (current + 1 < changes.length && changes[current + 1].at <= observedAt) current++;
    if (current < 0) continue;
    const price = changes[current].price;
    points.push(price === null ? { observedAt, inStock: false } : { observedAt, price, inStock: true });
  }
  return points;
}

// Daily points for the last `days` days from the Amazon price series; the buy box series only when Amazon
// never had an offer in the window.
export function parseKeepaProduct(product: KeepaProduct, { now, days }: { now: number; days: number }) {
  const amazon = dailySamples(decodeChanges(product.csv?.[AMAZON], 2), now, days);
  const buyBox = dailySamples(decodeChanges(product.csv?.[BUY_BOX_SHIPPING], 3), now, days);
  const hasOffer = (points: KeepaPoint[]) => points.some((p) => p.inStock);
  const series: KeepaSeries = hasOffer(amazon) ? "amazon" : hasOffer(buyBox) ? "buybox" : "none";
  return {
    asin: product.asin,
    title: product.title,
    upc: product.upcList?.[0],
    ean: product.eanList?.[0],
    series,
    points: series === "amazon" ? amazon : series === "buybox" ? buyBox : [],
  };
}

// Search response: products (full objects) in Amazon's result order.
export function parseKeepaSearch(json: unknown, limit = 5): { asin: string; title: string }[] {
  const products = (json as { products?: KeepaProduct[] })?.products ?? [];
  return products
    .filter((p): p is KeepaProduct & { asin: string; title: string } => !!p.asin && !!p.title)
    .slice(0, limit)
    .map((p) => ({ asin: p.asin, title: p.title }));
}

export const productAsin = internalQuery({
  args: { productId: v.id("products") },
  handler: async (ctx, args) => {
    const product = await ctx.db.get(args.productId);
    return product ? { asin: product.identifiers?.asin ?? null } : null;
  },
});

type KeepaResponse = { products?: KeepaProduct[]; tokensLeft?: number };

async function fetchProduct(key: string, asin: string, days: number, withOffers: boolean) {
  const url = new URL("https://api.keepa.com/product");
  url.searchParams.set("key", key);
  url.searchParams.set("domain", US_DOMAIN);
  url.searchParams.set("asin", asin);
  url.searchParams.set("history", "1");
  url.searchParams.set("days", String(days));
  if (withOffers) url.searchParams.set("offers", "20");
  const res = await fetch(url);
  return { res, json: res.ok ? ((await res.json()) as KeepaResponse) : undefined };
}

// Writes up to `days` daily Amazon points for a product with an ASIN. Idempotent: recordBatch skips days already
// stored for the same provider. The buy box needs the paid `offers` parameter, so it is requested only when the
// cheap 1-token request shows Amazon never sold the product in the window.
export const ingestHistory = internalAction({
  args: { productId: v.id("products"), days: v.optional(v.number()) },
  handler: async (ctx, args) => {
    const key = process.env.KEEPA_API_KEY;
    const empty = { recorded: 0, series: "none" as KeepaSeries, tokensLeft: null as number | null, latencyMs: 0 };
    if (!key) return { status: "no_key" as const, ...empty };
    const product: { asin: string | null } | null = await ctx.runQuery(internal.data.sources.keepa.productAsin, { productId: args.productId });
    if (!product) return { status: "unknown_product" as const, ...empty };
    if (!product.asin) return { status: "no_asin" as const, ...empty };
    const days = Math.min(Math.max(Math.floor(args.days ?? 365), 1), 1500);
    const now = Date.now();
    const started = now;

    let response = await fetchProduct(key, product.asin, days, false);
    let tokensLeft = response.json?.tokensLeft ?? null;
    let parsed = response.json?.products?.[0] && parseKeepaProduct(response.json.products[0], { now, days });
    if (parsed?.series === "none") {
      response = await fetchProduct(key, product.asin, days, true);
      tokensLeft = response.json?.tokensLeft ?? tokensLeft;
      parsed = response.json?.products?.[0] && parseKeepaProduct(response.json.products[0], { now, days });
    }
    const latencyMs = Date.now() - started;
    if (response.res.status === 429) return { status: "rate_limited" as const, ...empty, tokensLeft, latencyMs };
    if (!response.res.ok) return { status: "error" as const, httpStatus: response.res.status, ...empty, latencyMs };
    if (!parsed) return { status: "not_found" as const, ...empty, tokensLeft, latencyMs };

    const provider = parsed.series === "buybox" ? "keepa-buybox" : "keepa-amazon";
    const url = `https://www.amazon.com/dp/${product.asin}`;
    let recorded = 0;
    for (let i = 0; i < parsed.points.length; i += MAX_BATCH) {
      const r: { recorded: number } = await ctx.runMutation(internal.data.prices.recordBatch, {
        productId: args.productId as Id<"products">,
        retailer: "amazon",
        source: "api",
        provider,
        points: parsed.points.slice(i, i + MAX_BATCH).map((p) => ({ ...p, url })),
      });
      recorded += r.recorded;
    }
    return { status: "ok" as const, recorded, series: parsed.series, tokensLeft, latencyMs };
  },
});

// Finds candidate ASINs for an unknown product. Costs 10 tokens per search; history=0 keeps the response small.
export const searchAsins = internalAction({
  args: { term: v.string() },
  handler: async (_ctx, args) => {
    const key = process.env.KEEPA_API_KEY;
    if (!key) return { status: "no_key" as const, results: [] as { asin: string; title: string }[], tokensLeft: null as number | null, latencyMs: 0 };
    const url = new URL("https://api.keepa.com/search");
    url.searchParams.set("key", key);
    url.searchParams.set("domain", US_DOMAIN);
    url.searchParams.set("type", "product");
    url.searchParams.set("term", args.term);
    url.searchParams.set("history", "0");
    const started = Date.now();
    const res = await fetch(url);
    const latencyMs = Date.now() - started;
    if (!res.ok) {
      return { status: res.status === 429 ? ("rate_limited" as const) : ("error" as const), results: [], tokensLeft: null, latencyMs };
    }
    const json = (await res.json()) as KeepaResponse;
    return { status: "ok" as const, results: parseKeepaSearch(json), tokensLeft: json.tokensLeft ?? null, latencyMs };
  },
});
