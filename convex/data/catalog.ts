import { v } from "convex/values";
import { internalMutation, internalQuery, type QueryCtx } from "../_generated/server";
import type { Doc, Id } from "../_generated/dataModel";
import { buildSearchText, sizeTokens, tokenize, variantConflict } from "./text";

// What the agent sees of a product: everything except the internal search text.
export function productView(p: Doc<"products">) {
  const { searchText: _searchText, ...rest } = p;
  return rest;
}

type Candidate = {
  product: ReturnType<typeof productView>;
  score: number;
  matchedTokens: string[];
  sizeConflict: boolean;
  variantConflict?: boolean;
};

// Deterministic re-rank of full-text hits: share of the query's tokens the product carries,
// with size tokens (128gb, 4qt) and model-like tokens (digits) weighted higher.
export function scoreCandidate(queryTokens: string[], product: Doc<"products">): Candidate {
  const productTokens = new Set(product.searchText.split(" "));
  const weight = (t: string) => (sizeTokens([t]).length ? 3 : /\d/.test(t) ? 2 : 1);
  let total = 0;
  let hit = 0;
  const matched: string[] = [];
  for (const t of queryTokens) {
    total += weight(t);
    if (productTokens.has(t)) {
      hit += weight(t);
      matched.push(t);
    }
  }
  const unit = (s: string) => s.replace(/^[\d.]+/, "");
  const querySizes = sizeTokens(queryTokens);
  const productSizes = sizeTokens([...productTokens]);
  const sizeConflict = querySizes.some(
    (q) => productSizes.some((p) => unit(p) === unit(q)) && !productSizes.includes(q),
  );
  // A sibling model number (XM4 scanned, XM5 stored), another line (iPad Air vs iPad) or an accessory (ear pads)
  // halves the score, below viable.
  const otherProduct = variantConflict(queryTokens, productTokens);
  const score = total === 0 ? 0 : (hit / total) * (sizeConflict ? 0.6 : 1) * (otherProduct ? 0.5 : 1);
  return {
    product: productView(product),
    score: Math.round(score * 1000) / 1000,
    matchedTokens: matched,
    sizeConflict,
    variantConflict: otherProduct,
  };
}

async function fullText(ctx: QueryCtx, query: string, category: string | undefined, limit: number) {
  const text = tokenize(query).join(" ");
  if (!text) return [];
  return ctx.db
    .query("products")
    .withSearchIndex("search_text", (q) =>
      category ? q.search("searchText", text).eq("category", category) : q.search("searchText", text),
    )
    .take(limit);
}

export const searchCatalog = internalQuery({
  args: { query: v.string(), category: v.optional(v.string()), limit: v.optional(v.number()) },
  handler: async (ctx, args) => {
    const hits = await fullText(ctx, args.query, args.category, Math.min(args.limit ?? 10, 50));
    return hits.map(productView);
  },
});

// Best catalog matches for a scanned title. The agent decides among them, or says none fit.
export const matchProduct = internalQuery({
  args: { title: v.string(), category: v.optional(v.string()), limit: v.optional(v.number()) },
  handler: async (ctx, args) => {
    const queryTokens = tokenize(args.title);
    const all = await fullText(ctx, args.title, args.category, 25);
    const real = all.filter((p) => !p.provisional);
    const hits = real.length ? real : all;
    return hits
      .map((p) => scoreCandidate(queryTokens, p))
      .sort((a, b) => b.score - a.score)
      .slice(0, Math.min(args.limit ?? 5, 25));
  },
});

export const getProduct = internalQuery({
  args: { productId: v.id("products") },
  handler: async (ctx, args) => {
    const p = await ctx.db.get(args.productId);
    return p ? productView(p) : null;
  },
});

// Variants of one model (e.g. 128GB and 256GB), which must not be confused with each other.
export const listFamily = internalQuery({
  args: { familyKey: v.string() },
  handler: async (ctx, args) => {
    const rows = await ctx.db
      .query("products")
      .withIndex("by_family", (q) => q.eq("familyKey", args.familyKey))
      .take(20);
    return rows.map(productView);
  },
});

// Same-category products from other families; the agent judges which are truly comparable.
export const findComparables = internalQuery({
  args: { productId: v.id("products"), limit: v.optional(v.number()) },
  handler: async (ctx, args) => {
    const product = await ctx.db.get(args.productId);
    if (!product) return [];
    const rows = await ctx.db
      .query("products")
      .withIndex("by_category", (q) => q.eq("category", product.category))
      .take(100);
    return rows
      .filter((p) => p.familyKey !== product.familyKey && !p.provisional)
      .slice(0, Math.min(args.limit ?? 10, 25))
      .map(productView);
  },
});

// An unmatched scan becomes a provisional product: real, but with no history yet (thin evidence).
export const createProvisionalProduct = internalMutation({
  args: { title: v.string(), brand: v.optional(v.string()), category: v.optional(v.string()) },
  handler: async (ctx, args): Promise<Id<"products">> => {
    const familyKey = "provisional-" + tokenize(args.title).slice(0, 6).join("-");
    const existing = await ctx.db
      .query("products")
      .withIndex("by_family", (q) => q.eq("familyKey", familyKey))
      .first();
    if (existing) return existing._id;
    return ctx.db.insert("products", {
      title: args.title.trim(),
      brand: args.brand ?? "unknown",
      category: args.category ?? "unknown",
      familyKey,
      specs: {},
      aliases: [],
      searchText: buildSearchText([args.title, args.brand]),
      isSample: false,
      provisional: true,
    });
  },
});
