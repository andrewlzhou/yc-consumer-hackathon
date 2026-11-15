import { v } from "convex/values";
import { internalMutation, type MutationCtx } from "../_generated/server";
import type { TableNames } from "../_generated/dataModel";
import { refreshDigestFor } from "../data/digests";
import { KNOWN_RETAILERS } from "../data/retailers";
import { buildSearchText } from "../data/text";
import { SEED_EVENTS, SEED_PRODUCTS } from "./catalog";
import { generateTrack, SEED_NOW } from "./generate";
import { SEED_TRACKS } from "./tracks";

const DATA_TABLES: TableNames[] = ["priceDigests", "priceObservations", "saleEvents", "products", "retailers"];

const eventTime = (iso: string, endOfDay: boolean) =>
  Date.UTC(+iso.slice(0, 4), +iso.slice(5, 7) - 1, +iso.slice(8, 10) + (endOfDay ? 1 : 0), 8) - (endOfDay ? 1 : 0);

async function clearDataTables(ctx: MutationCtx) {
  let deleted = 0;
  for (const table of DATA_TABLES) {
    for await (const doc of ctx.db.query(table)) {
      await ctx.db.delete(doc._id);
      deleted++;
    }
  }
  return deleted;
}

// One command: `npm run seed`. Wipes the data tables (not other threads' tables) and reloads the demo set.
// The same code and SEED_NOW always produce the same rows.
export const all = internalMutation({
  args: {},
  handler: async (ctx) => {
    const deleted = await clearDataTables(ctx);
    for (const r of KNOWN_RETAILERS) await ctx.db.insert("retailers", { slug: r.slug, name: r.name, domain: r.domain });
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
    let observations = 0;
    const products: Record<string, string> = {};
    for (const p of SEED_PRODUCTS) {
      const productId = await ctx.db.insert("products", {
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
      });
      products[p.key] = productId;
      for (const track of SEED_TRACKS[p.key] ?? []) {
        for (const point of generateTrack(track, p.key)) {
          await ctx.db.insert("priceObservations", { productId, ...point, source: "seed" });
          observations++;
        }
      }
      await refreshDigestFor(ctx, productId, SEED_NOW);
    }
    return { deleted, products, observations, events: SEED_EVENTS.length, now: SEED_NOW };
  },
});

export const clear = internalMutation({
  args: { confirm: v.literal("delete seed and data tables") },
  handler: async (ctx) => ({ deleted: await clearDataTables(ctx) }),
});
