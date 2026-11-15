import { v } from "convex/values";
import { internal } from "../_generated/api";
import type { Id } from "../_generated/dataModel";
import { internalAction, internalMutation, internalQuery } from "../_generated/server";
import { SEED_PRODUCTS, type SeedProduct } from "../seed/catalog";
import { deleteSeedObservations } from "../seed/run";
import { refreshDigestFor } from "./digests";
import { embedProducts } from "./embeddings";
import { refreshProduct } from "./sources/serpapi";
import { ingestWayback } from "./sources/wayback";
import { buildSearchText } from "./text";

// The real-data demo set, picked 2026-11-15 by how much real history exists (docs/backend/data-demo.md).
// History comes from Google's per-store price history via SerpApi, archived product pages (Wayback), and the
// daily SerpApi refresh. These products carry no seed points: turning one real deletes its seeded history.
type DemoProduct = SeedProduct & { googleProductId?: string; wayback?: { retailer: string; url: string }[] };

const fromSeed = (key: string, extra: Omit<DemoProduct, keyof SeedProduct>): DemoProduct => ({
  ...SEED_PRODUCTS.find((p) => p.key === key)!,
  ...extra,
});

export const DEMO_PRODUCTS: DemoProduct[] = [
  fromSeed("sony-xm5", {
    googleProductId: "17755277695162489284",
    wayback: [
      { retailer: "bestbuy", url: "https://www.bestbuy.com/product/sony-wh-1000xm5-wireless-noise-cancelling-over-the-ear-headphones-black/J7XSRH5CXG" },
      { retailer: "walmart", url: "https://www.walmart.com/ip/Sony-WH-1000XM5-The-Best-Wireless-Noise-Canceling-Headphones-Black/386006068" },
    ],
  }),
  fromSeed("sony-xm6", { googleProductId: "5636327565946258541" }),
  fromSeed("bose-qcu-2", { googleProductId: "18005777686068683712" }),
  fromSeed("airpods-pro-3", {
    googleProductId: "2327420681279440941",
    wayback: [
      { retailer: "bestbuy", url: "https://www.bestbuy.com/product/apple-airpods-pro-3-wireless-active-noise-cancelling-earbuds-with-heart-rate-sensing-feature-white/JJGCQLYK5F" },
    ],
  }),
  {
    key: "ps5-slim-disc",
    title: "Sony PlayStation 5 Slim Console Disc Edition 1TB",
    brand: "Sony",
    model: "CFI-2015",
    category: "game-consoles",
    familyKey: "sony-ps5-slim-disc",
    aliases: ["PS5 Slim", "PlayStation 5 Slim Disc", "PS5 Slim Disc Edition 1TB"],
    msrp: 549.99,
    specs: { storageGb: 1024, discDrive: true, releaseDate: "2023-11-10" },
    googleProductId: "4709235825987841660",
  },
];

const sameVariant = (a?: Record<string, string>, b?: Record<string, string>) => JSON.stringify(a ?? {}) === JSON.stringify(b ?? {});

// Creates the product, or turns the existing seeded row real in place so ids held by watchlists survive.
export const ensureDemoProduct = internalMutation({
  args: { key: v.string() },
  handler: async (ctx, args) => {
    const p = DEMO_PRODUCTS.find((x) => x.key === args.key);
    if (!p) throw new Error("unknown demo product " + args.key);
    const family = await ctx.db.query("products").withIndex("by_family", (q) => q.eq("familyKey", p.familyKey)).take(20);
    const existing = family.find((x) => sameVariant(x.variant, p.variant));
    const doc = {
      title: p.title,
      brand: p.brand,
      model: p.model,
      category: p.category,
      familyKey: p.familyKey,
      variant: p.variant,
      specs: p.specs,
      aliases: p.aliases,
      searchText: buildSearchText([p.title, p.brand, p.model, ...p.aliases, ...Object.values(p.variant ?? {})]),
      identifiers: { ...existing?.identifiers, ...p.identifiers, googleProductId: p.googleProductId },
      msrp: p.msrp,
      isSample: false,
      provisional: false,
    };
    if (!existing) return { productId: await ctx.db.insert("products", doc), deletedSeedPoints: 0 };
    await ctx.db.replace(existing._id, doc);
    return { productId: existing._id, deletedSeedPoints: await deleteSeedObservations(ctx, existing._id) };
  },
});

export const finishDemoProduct = internalMutation({
  args: { productId: v.id("products") },
  handler: (ctx, args) => refreshDigestFor(ctx, args.productId, Date.now()),
});

// Backfill one demo product: SerpApi (1 search: offers + Google's price history), then archived pages.
// Run per product so each action stays well inside the 10-minute action limit:
// npx convex run data/demo:ingest '{"key":"sony-xm5"}'
export const ingest = internalAction({
  args: { key: v.string(), wayback: v.optional(v.boolean()) },
  handler: async (ctx, args) => {
    const p = DEMO_PRODUCTS.find((x) => x.key === args.key);
    if (!p) throw new Error("unknown demo product " + args.key);
    const ensured: { productId: Id<"products">; deletedSeedPoints: number } = await ctx.runMutation(internal.data.demo.ensureDemoProduct, { key: p.key });
    await embedProducts(ctx, [ensured.productId]);
    const serpapi = await refreshProduct(ctx, ensured.productId);
    const wayback = [];
    for (const w of args.wayback === false ? [] : (p.wayback ?? [])) {
      wayback.push({ retailer: w.retailer, ...(await ingestWayback(ctx, { productId: ensured.productId, retailer: w.retailer, url: w.url })) });
    }
    await ctx.runMutation(internal.data.demo.finishDemoProduct, { productId: ensured.productId });
    return { productId: ensured.productId, deletedSeedPoints: ensured.deletedSeedPoints, serpapi, wayback };
  },
});

export const demoProductIds = internalQuery({
  args: {},
  handler: async (ctx) => {
    const ids: Id<"products">[] = [];
    for (const p of DEMO_PRODUCTS) {
      const family = await ctx.db.query("products").withIndex("by_family", (q) => q.eq("familyKey", p.familyKey)).take(20);
      const row = family.find((x) => !x.isSample && sameVariant(x.variant, p.variant));
      if (row) ids.push(row._id);
    }
    return ids;
  },
});

// Daily cron: one SerpApi search per demo product that has been ingested (5 a day, inside the free 250/month).
export const refreshDaily = internalAction({
  args: {},
  handler: async (ctx) => {
    const ids: Id<"products">[] = await ctx.runQuery(internal.data.demo.demoProductIds, {});
    const results = [];
    for (const productId of ids) {
      const r = await refreshProduct(ctx, productId);
      await ctx.runMutation(internal.data.demo.finishDemoProduct, { productId });
      results.push({ productId, status: r.status, recorded: r.recorded });
    }
    return results;
  },
});

// Operator cleanup for rows a past bug wrote (e.g. a wrong-product offer): deletes one product's rows from one
// provider at one exact observedAt. npx convex run data/demo:removeObservationsAt '{"productId":"…","provider":"…","observedAt":…}'
export const removeObservationsAt = internalMutation({
  args: { productId: v.id("products"), provider: v.string(), observedAt: v.number() },
  handler: async (ctx, args) => {
    const rows = await ctx.db
      .query("priceObservations")
      .withIndex("by_product_and_observedAt", (q) => q.eq("productId", args.productId).eq("observedAt", args.observedAt))
      .take(50);
    const doomed = rows.filter((r) => r.provider === args.provider);
    for (const r of doomed) await ctx.db.delete(r._id);
    return { deleted: doomed.map((r) => ({ retailerSlug: r.retailerSlug, price: r.price })) };
  },
});
