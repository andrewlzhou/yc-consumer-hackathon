import { v } from "convex/values";
import { internalAction } from "../../_generated/server";

// Best Buy live price for display only. Needs BESTBUY_API_KEY. Unverified live until a key exists; the parser is
// tested against fixtures written from https://bestbuyapis.github.io/api-documentation/ (Products API).
// Best Buy's terms forbid caching content except temporarily, so this adapter never writes observations.

export type BestBuyOffer = { sku: number; name: string; regularPrice: number; salePrice: number; onSale: boolean; url?: string };

type BestBuyProduct = { sku?: number; name?: string; regularPrice?: number; salePrice?: number; onSale?: boolean; url?: string };

const SHOW_FIELDS = "sku,name,regularPrice,salePrice,onSale,url";
const MAX_RESULTS = 5;

// A collection response has a products array; a single-SKU request (/products/{sku}.json) returns the product itself.
export function parseBestBuyProducts(json: unknown): BestBuyOffer[] {
  const body = json as { products?: BestBuyProduct[] } & BestBuyProduct;
  const products = Array.isArray(body?.products) ? body.products : body?.sku !== undefined ? [body] : [];
  const offers: BestBuyOffer[] = [];
  for (const p of products) {
    if (typeof p.sku !== "number" || !p.name || typeof p.salePrice !== "number") continue;
    const regularPrice = typeof p.regularPrice === "number" ? p.regularPrice : p.salePrice;
    offers.push({
      sku: p.sku,
      name: p.name,
      regularPrice,
      salePrice: p.salePrice,
      onSale: typeof p.onSale === "boolean" ? p.onSale : p.salePrice < regularPrice,
      url: p.url,
    });
  }
  return offers;
}

// Keyword search needs "&" between words (AND); a bare space would be treated as OR.
function buildUrl(key: string, args: { query?: string; sku?: string }): URL | null {
  const sku = args.sku?.replace(/\D/g, "");
  const words = (args.query ?? "").split(/\s+/).map((w) => w.replace(/[^A-Za-z0-9-]/g, "")).filter(Boolean).slice(0, 8);
  const url = sku
    ? new URL(`https://api.bestbuy.com/v1/products/${sku}.json`)
    : words.length
      ? new URL(`https://api.bestbuy.com/v1/products(${words.map((w) => `search=${w}`).join("&")})`)
      : null;
  if (!url) return null;
  url.searchParams.set("show", SHOW_FIELDS);
  if (!sku) {
    url.searchParams.set("format", "json");
    url.searchParams.set("pageSize", String(MAX_RESULTS));
  }
  url.searchParams.set("apiKey", key);
  return url;
}

export const getLivePrice = internalAction({
  args: { query: v.optional(v.string()), sku: v.optional(v.string()) },
  handler: async (_ctx, args) => {
    const key = process.env.BESTBUY_API_KEY;
    const none = { offers: [] as BestBuyOffer[], latencyMs: 0 };
    if (!key) return { status: "no_key" as const, ...none };
    const url = buildUrl(key, args);
    if (!url) return { status: "no_query" as const, ...none };
    const started = Date.now();
    const res = await fetch(url);
    const latencyMs = Date.now() - started;
    if (!res.ok) return { status: "error" as const, httpStatus: res.status, offers: [], latencyMs };
    return { status: "ok" as const, offers: parseBestBuyProducts(await res.json()).slice(0, MAX_RESULTS), latencyMs };
  },
});
