import { v } from "convex/values";
import { internal } from "../_generated/api";
import type { Doc, Id } from "../_generated/dataModel";
import { internalAction, internalMutation, internalQuery, type ActionCtx } from "../_generated/server";
import { productView, scoreCandidate } from "./catalog";
import { tokenize } from "./text";

// OpenAI text-embedding-3-small (1536 dims) over product titles and specs, for hybrid catalog search.
// Without OPENAI_API_KEY every function here falls back to text-only matching.

const MODEL = "text-embedding-3-small";
const RRF_K = 20;

export function productEmbeddingText(p: Pick<Doc<"products">, "title" | "brand" | "model" | "category" | "variant" | "aliases" | "specs">) {
  const specs = Object.entries(p.specs).map(([k, val]) => `${k}: ${val}`).join("; ");
  const variant = Object.values(p.variant ?? {}).join(" ");
  return [p.brand, p.title, p.model, variant, p.category, p.aliases.join(", "), specs].filter(Boolean).join(" | ");
}

export async function embedTexts(texts: string[]): Promise<number[][] | null> {
  const key = process.env.OPENAI_API_KEY;
  if (!key || texts.length === 0) return null;
  const res = await fetch("https://api.openai.com/v1/embeddings", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
    body: JSON.stringify({ model: MODEL, input: texts }),
  });
  if (!res.ok) throw new Error(`OpenAI embeddings failed: HTTP ${res.status}`);
  const json = (await res.json()) as { data: { index: number; embedding: number[] }[] };
  return [...json.data].sort((a, b) => a.index - b.index).map((d) => d.embedding);
}

const PAGE = 100;

// One page of products that still need a vector (or the given ones). Pages through the whole catalog by cursor.
export const productsToEmbed = internalQuery({
  args: { productIds: v.optional(v.array(v.id("products"))), cursor: v.optional(v.union(v.string(), v.null())) },
  handler: async (ctx, args) => {
    const page = args.productIds
      ? { page: (await Promise.all(args.productIds.map((id) => ctx.db.get(id)))).filter((p): p is Doc<"products"> => p !== null), isDone: true, continueCursor: "" }
      : await ctx.db.query("products").paginate({ numItems: PAGE, cursor: args.cursor ?? null });
    const todo: { id: Id<"products">; text: string }[] = [];
    for (const p of page.page) {
      const existing = await ctx.db.query("productEmbeddings").withIndex("by_productId", (q) => q.eq("productId", p._id)).first();
      if (!existing || args.productIds) todo.push({ id: p._id, text: productEmbeddingText(p) });
    }
    return { todo, isDone: page.isDone, cursor: page.continueCursor };
  },
});

export const setEmbedding = internalMutation({
  args: { productId: v.id("products"), embedding: v.array(v.float64()) },
  handler: async (ctx, args) => {
    const product = await ctx.db.get(args.productId);
    if (!product) return;
    const doc = { productId: args.productId, category: product.category, model: MODEL, embedding: args.embedding };
    const existing = await ctx.db.query("productEmbeddings").withIndex("by_productId", (q) => q.eq("productId", args.productId)).first();
    if (existing) await ctx.db.replace(existing._id, doc);
    else await ctx.db.insert("productEmbeddings", doc);
  },
});

export async function embedProducts(ctx: ActionCtx, productIds?: Id<"products">[]): Promise<{ status: "ok" | "no_key"; embedded: number }> {
  let embedded = 0;
  let cursor: string | null = null;
  for (;;) {
    const page: { todo: { id: Id<"products">; text: string }[]; isDone: boolean; cursor: string } = await ctx.runQuery(
      internal.data.embeddings.productsToEmbed,
      { productIds, cursor },
    );
    if (page.todo.length) {
      const vectors = await embedTexts(page.todo.map((b) => b.text));
      if (!vectors) return { status: "no_key", embedded };
      for (let j = 0; j < page.todo.length; j++) {
        await ctx.runMutation(internal.data.embeddings.setEmbedding, { productId: page.todo[j].id, embedding: vectors[j] });
        embedded++;
      }
    }
    if (page.isDone) return { status: "ok", embedded };
    cursor = page.cursor;
  }
}

// Backfill: embeds every product that has no vector yet, or re-embeds the given ones.
export const embedCatalog = internalAction({
  args: { productIds: v.optional(v.array(v.id("products"))) },
  handler: (ctx, args) => embedProducts(ctx, args.productIds),
});

// Vector hits point at productEmbeddings rows; this returns their products in hit order.
export const productsForHits = internalQuery({
  args: { ids: v.array(v.id("productEmbeddings")) },
  handler: async (ctx, args) => {
    const out: Doc<"products">[] = [];
    for (const id of args.ids) {
      const e = await ctx.db.get(id);
      const p = e ? await ctx.db.get(e.productId) : null;
      if (p) out.push(p);
    }
    return out;
  },
});

export const productWithEmbedding = internalQuery({
  args: { productId: v.id("products") },
  handler: async (ctx, args) => {
    const product = await ctx.db.get(args.productId);
    if (!product) return null;
    const e = await ctx.db.query("productEmbeddings").withIndex("by_productId", (q) => q.eq("productId", args.productId)).first();
    return { product, embedding: e?.embedding ?? null };
  },
});

type Candidate = ReturnType<typeof scoreCandidate>;
type HybridCandidate = Candidate & { vectorScore: number | null; fused: number };
export type HybridResult = { mode: "text" | "hybrid"; candidates: HybridCandidate[] };
type Similar = { mode: "none" | "category" | "vector"; products: { product: ReturnType<typeof productView>; similarity: number | null }[] };

// Reciprocal rank fusion of full-text and vector hits. Each candidate keeps its token score and size
// conflict flag, so the agent still sees why something matched.
export function fuse(text: Candidate[], vector: { product: Doc<"products">; score: number }[], queryTokens: string[]): HybridCandidate[] {
  const out = new Map<string, HybridCandidate>();
  text.forEach((c, rank) => out.set(c.product._id, { ...c, vectorScore: null, fused: 1 / (RRF_K + rank + 1) }));
  vector.forEach((hit, rank) => {
    const existing = out.get(hit.product._id);
    const add = 1 / (RRF_K + rank + 1);
    if (existing) {
      existing.vectorScore = Math.round(hit.score * 1000) / 1000;
      existing.fused += add;
    } else {
      out.set(hit.product._id, { ...scoreCandidate(queryTokens, hit.product), vectorScore: Math.round(hit.score * 1000) / 1000, fused: add });
    }
  });
  return [...out.values()]
    .map((c) => ({ ...c, fused: Math.round(c.fused * (c.sizeConflict ? 0.5 : 1) * 10000) / 10000 }))
    .sort((a, b) => b.fused - a.fused);
}

export async function hybridSearch(ctx: ActionCtx, title: string, opts: { category?: string; limit?: number } = {}): Promise<HybridResult> {
  const limit = Math.min(opts.limit ?? 5, 25);
  const text: Candidate[] = await ctx.runQuery(internal.data.catalog.matchProduct, { title, category: opts.category, limit: 10 });
  const vectors = await embedTexts([title]);
  if (!vectors) return { mode: "text", candidates: text.slice(0, limit).map((c) => ({ ...c, vectorScore: null, fused: c.score })) };
  const hits = await ctx.vectorSearch("productEmbeddings", "by_embedding", {
    vector: vectors[0],
    limit: 10,
    filter: opts.category ? (q) => q.eq("category", opts.category!) : undefined,
  });
  const docs: Doc<"products">[] = await ctx.runQuery(internal.data.embeddings.productsForHits, { ids: hits.map((h) => h._id) });
  const vector = docs.map((product, i) => ({ product, score: hits[i]._score }));
  const fused = fuse(text, vector.filter((x) => !x.product.provisional), tokenize(title));
  return { mode: "hybrid", candidates: fused.filter((c) => !c.variantConflict).slice(0, limit) };
}

// Best catalog matches for a messy scanned title: full-text plus vector search when embeddings exist.
export const hybridMatch = internalAction({
  args: { title: v.string(), category: v.optional(v.string()), limit: v.optional(v.number()) },
  handler: (ctx, args) => hybridSearch(ctx, args.title, args),
});

// Products most similar to this one in the same category, for competitor discovery. Falls back to category listing.
export const findSimilarProducts = internalAction({
  args: { productId: v.id("products"), limit: v.optional(v.number()) },
  handler: async (ctx, args): Promise<Similar> => {
    const found: { product: Doc<"products">; embedding: number[] | null } | null = await ctx.runQuery(internal.data.embeddings.productWithEmbedding, { productId: args.productId });
    if (!found) return { mode: "none", products: [] };
    const { product, embedding } = found;
    const limit = Math.min(args.limit ?? 5, 20);
    if (!embedding) {
      const comps: ReturnType<typeof productView>[] = await ctx.runQuery(internal.data.catalog.findComparables, { productId: args.productId, limit });
      return { mode: "category", products: comps.map((p) => ({ product: p, similarity: null })) };
    }
    const hits = await ctx.vectorSearch("productEmbeddings", "by_embedding", {
      vector: embedding,
      limit: limit + 10,
      filter: (q) => q.eq("category", product.category),
    });
    const docs: Doc<"products">[] = await ctx.runQuery(internal.data.embeddings.productsForHits, { ids: hits.map((h) => h._id) });
    return {
      mode: "vector",
      products: docs
        .map((d, i) => ({ d, score: hits[i]._score }))
        .filter(({ d }) => d.familyKey !== product.familyKey && !d.provisional)
        .slice(0, limit)
        .map(({ d, score }) => ({ product: productView(d), similarity: Math.round(score * 1000) / 1000 })),
    };
  },
});

