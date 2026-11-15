import { v } from "convex/values";
import { internal } from "../_generated/api";
import { internalAction, internalMutation, type MutationCtx } from "../_generated/server";
import type { Id, TableNames } from "../_generated/dataModel";
import { refreshDigestFor } from "../data/digests";
import { KNOWN_RETAILERS } from "../data/retailers";
import { buildSearchText } from "../data/text";
import { SEED_EVENTS, SEED_PRODUCTS, type SeedProduct } from "./catalog";
import { generateTrack, SEED_NOW } from "./generate";
import { SEED_TRACKS } from "./tracks";

const eventTime = (iso: string, endOfDay: boolean) =>
  Date.UTC(+iso.slice(0, 4), +iso.slice(5, 7) - 1, +iso.slice(8, 10) + (endOfDay ? 1 : 0), 8) - (endOfDay ? 1 : 0);

const sameVariant = (a?: Record<string, string>, b?: Record<string, string>) =>
  JSON.stringify(a ?? {}) === JSON.stringify(b ?? {});

// Seeded products keep their ids across reseeds, so watchlists and analyses that point at them survive.
async function upsertProduct(ctx: MutationCtx, p: SeedProduct): Promise<Id<"products">> {
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
    identifiers: p.identifiers,
    msrp: p.msrp,
    isSample: true,
    provisional: false,
  };
  const family = await ctx.db
    .query("products")
    .withIndex("by_family", (q) => q.eq("familyKey", p.familyKey))
    .take(20);
  const existing = family.find((x) => x.isSample && sameVariant(x.variant, p.variant));
  if (!existing) return ctx.db.insert("products", doc);
  await ctx.db.replace(existing._id, doc);
  return existing._id;
}

async function deleteSeedObservations(ctx: MutationCtx, productId: Id<"products">) {
  let deleted = 0;
  for await (const o of ctx.db.query("priceObservations").withIndex("by_product_and_observedAt", (q) => q.eq("productId", productId))) {
    if (o.source !== "seed") continue;
    await ctx.db.delete(o._id);
    deleted++;
  }
  return deleted;
}

async function clearTable(ctx: MutationCtx, table: TableNames) {
  for await (const doc of ctx.db.query(table)) await ctx.db.delete(doc._id);
}

export const seedCalendar = internalMutation({
  args: {},
  handler: async (ctx) => {
    for (const r of KNOWN_RETAILERS) {
      const existing = await ctx.db.query("retailers").withIndex("by_slug", (q) => q.eq("slug", r.slug)).first();
      const doc = { slug: r.slug, name: r.name, domain: r.domain };
      if (existing) await ctx.db.replace(existing._id, doc);
      else await ctx.db.insert("retailers", doc);
    }
    await clearTable(ctx, "saleEvents");
    for (const e of SEED_EVENTS) {
      await ctx.db.insert("saleEvents", {
        name: e.name,
        series: e.series,
        retailerSlug: e.retailerSlug,
        startsAt: eventTime(e.start, false),
        endsAt: eventTime(e.end, true),
        kind: e.kind,
        dateConfidence: e.dateConfidence,
      });
    }
    return SEED_EVENTS.length;
  },
});

// One product per transaction keeps each mutation well under Convex's read and write limits.
export const seedProduct = internalMutation({
  args: { key: v.string() },
  handler: async (ctx, args) => {
    const p = SEED_PRODUCTS.find((x) => x.key === args.key);
    if (!p) throw new Error("unknown seed product " + args.key);
    const productId = await upsertProduct(ctx, p);
    const deleted = await deleteSeedObservations(ctx, productId);
    let observations = 0;
    for (const track of SEED_TRACKS[p.key] ?? []) {
      for (const point of generateTrack(track, p.key)) {
        await ctx.db.insert("priceObservations", { productId, ...point, source: "seed", provider: "seed-generator" });
        observations++;
      }
    }
    await refreshDigestFor(ctx, productId, SEED_NOW);
    return { productId, observations, deleted };
  },
});

// One command: `npm run seed`. Rebuilds the demo catalog, sale calendar, seeded history, and digests.
// Same code + SEED_NOW gives the same rows; real scan and api observations are left alone.
export const all = internalAction({
  args: {},
  handler: async (ctx) => {
    const events: number = await ctx.runMutation(internal.seed.run.seedCalendar, {});
    let observations = 0;
    let deleted = 0;
    const products: Record<string, Id<"products">> = {};
    for (const p of SEED_PRODUCTS) {
      const r: { productId: Id<"products">; observations: number; deleted: number } = await ctx.runMutation(
        internal.seed.run.seedProduct,
        { key: p.key },
      );
      products[p.key] = r.productId;
      observations += r.observations;
      deleted += r.deleted;
    }
    return { products, observations, deletedSeedObservations: deleted, events, now: SEED_NOW };
  },
});

// Removes every seeded product and its observations and digests (other threads' rows that point at them are not touched).
export const clear = internalMutation({
  args: { confirm: v.literal("delete seed data") },
  handler: async (ctx) => {
    let products = 0;
    for await (const p of ctx.db.query("products")) {
      if (!p.isSample) continue;
      await deleteSeedObservations(ctx, p._id);
      const embedding = await ctx.db.query("productEmbeddings").withIndex("by_productId", (q) => q.eq("productId", p._id)).first();
      if (embedding) await ctx.db.delete(embedding._id);
      const digest = await ctx.db.query("priceDigests").withIndex("by_productId", (q) => q.eq("productId", p._id)).unique();
      if (digest) await ctx.db.delete(digest._id);
      await ctx.db.delete(p._id);
      products++;
    }
    return { products };
  },
});
