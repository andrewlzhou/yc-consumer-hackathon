import { v } from "convex/values";
import { internal } from "../../_generated/api";
import type { Doc } from "../../_generated/dataModel";
import { internalAction, internalQuery } from "../../_generated/server";
import { scoreCandidate } from "../catalog";
import { KNOWN_RETAILERS } from "../retailers";
import { tokenize } from "../text";

// Current prices across retailers from SerpApi's Google Shopping engine. Needs SERPAPI_API_KEY.
// Unverified live until a key exists; the parser is tested against the documented response shape.

export type Offer = { retailerSlug: string; price: number; originalPrice?: number; url?: string; title: string };

type ShoppingResult = {
  title?: string;
  source?: string;
  extracted_price?: number;
  extracted_old_price?: number;
  product_link?: string;
  link?: string;
  second_hand_condition?: string;
};

const NOT_THE_PRODUCT = /\b(refurbished|renewed|pre-owned|used|case|cover|replacement|skin|protector|charger only)\b/i;
const MIN_TITLE_SCORE = 0.6;

// "Walmart" and "Best Buy" are the retailer itself; "Walmart - SellerName" is a marketplace seller, skipped.
function retailerFromSource(source: string | undefined): string | null {
  if (!source || source.includes(" - ")) return null;
  const s = source.toLowerCase().replace(/\.com$/, "").trim();
  return KNOWN_RETAILERS.find((r) => r.aliases.includes(s) || r.slug === s.replace(/\s+/g, ""))?.slug ?? null;
}

// First matching offer per known retailer; results that are accessories, used, or another variant are dropped.
export function parseShoppingResults(json: unknown, product: Doc<"products">): Offer[] {
  const results = (json as { shopping_results?: ShoppingResult[] })?.shopping_results ?? [];
  const offers = new Map<string, Offer>();
  for (const r of results) {
    const retailerSlug = retailerFromSource(r.source);
    if (!retailerSlug || offers.has(retailerSlug) || !r.title || r.second_hand_condition) continue;
    if (typeof r.extracted_price !== "number" || NOT_THE_PRODUCT.test(r.title)) continue;
    const match = scoreCandidate(tokenize(r.title), product);
    if (match.sizeConflict || match.score < MIN_TITLE_SCORE) continue;
    offers.set(retailerSlug, {
      retailerSlug,
      price: r.extracted_price,
      originalPrice: typeof r.extracted_old_price === "number" ? r.extracted_old_price : undefined,
      url: r.product_link ?? r.link,
      title: r.title,
    });
  }
  return [...offers.values()];
}

export const productForRefresh = internalQuery({
  args: { productId: v.id("products") },
  handler: (ctx, args) => ctx.db.get(args.productId),
});

export const refreshCurrentPrices = internalAction({
  args: { productId: v.id("products") },
  handler: async (ctx, args) => {
    const key = process.env.SERPAPI_API_KEY;
    if (!key) return { status: "no_key" as const, recorded: 0 };
    const product: Doc<"products"> | null = await ctx.runQuery(internal.data.sources.serpapi.productForRefresh, args);
    if (!product) return { status: "unknown_product" as const, recorded: 0 };
    const url = new URL("https://serpapi.com/search.json");
    url.searchParams.set("engine", "google_shopping");
    url.searchParams.set("q", [product.title, product.variant?.storage].filter(Boolean).join(" "));
    url.searchParams.set("gl", "us");
    url.searchParams.set("hl", "en");
    url.searchParams.set("api_key", key);
    const started = Date.now();
    const res = await fetch(url);
    if (!res.ok) return { status: "error" as const, httpStatus: res.status, recorded: 0 };
    const offers = parseShoppingResults(await res.json(), product);
    const observedAt = Date.now();
    let recorded = 0;
    for (const o of offers) {
      const r = await ctx.runMutation(internal.data.prices.recordObservation, {
        productId: args.productId,
        retailer: o.retailerSlug,
        price: o.price,
        originalPrice: o.originalPrice,
        observedAt,
        source: "api",
        provider: "serpapi-google-shopping",
        url: o.url,
      });
      if (r.status === "recorded") recorded++;
    }
    return { status: "ok" as const, recorded, offers, latencyMs: observedAt - started };
  },
});
