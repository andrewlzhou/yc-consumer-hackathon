import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";
import { observationSourceValidator } from "./lib/contract";
import { watchlistTables } from "./watchlist/tables";

const specValue = v.union(v.string(), v.number(), v.boolean());

export default defineSchema({
  // ---- Data & retrieval (convex/data, convex/seed) ----

  retailers: defineTable({
    slug: v.string(),
    name: v.string(),
    domain: v.optional(v.string()),
  }).index("by_slug", ["slug"]),

  // familyKey groups variants of one model (storage, size); variant holds what changes price.
  products: defineTable({
    title: v.string(),
    brand: v.string(),
    model: v.optional(v.string()),
    category: v.string(),
    familyKey: v.string(),
    variant: v.optional(v.record(v.string(), v.string())),
    specs: v.record(v.string(), specValue),
    aliases: v.array(v.string()),
    searchText: v.string(),
    identifiers: v.optional(
      v.object({
        gtin: v.optional(v.string()),
        asin: v.optional(v.string()),
        googleProductId: v.optional(v.string()),
        bestBuySku: v.optional(v.string()),
      }),
    ),
    msrp: v.optional(v.number()),
    isSample: v.boolean(),
    provisional: v.boolean(),
    embedding: v.optional(v.array(v.float64())),
  })
    .index("by_family", ["familyKey"])
    .index("by_category", ["category"])
    .searchIndex("search_text", {
      searchField: "searchText",
      filterFields: ["category", "brand"],
    })
    .vectorIndex("by_embedding", {
      vectorField: "embedding",
      dimensions: 1536,
      filterFields: ["category"],
    }),

  // One observed price. observedAt is when the price was true, not when the row was written.
  // price is absent only when the item was out of stock or hidden: missing, never zero.
  priceObservations: defineTable({
    productId: v.id("products"),
    retailerSlug: v.string(),
    price: v.optional(v.number()),
    originalPrice: v.optional(v.number()),
    inStock: v.boolean(),
    observedAt: v.number(),
    source: observationSourceValidator,
    provider: v.optional(v.string()),
    url: v.optional(v.string()),
  })
    .index("by_product_and_observedAt", ["productId", "observedAt"])
    .index("by_product_and_retailerSlug_and_observedAt", [
      "productId",
      "retailerSlug",
      "observedAt",
    ]),

  // Sale calendar: national events (retailerSlug absent) and retailer-specific sales.
  // series links the same event across years ("black-friday") so recurrence can be checked.
  saleEvents: defineTable({
    name: v.string(),
    series: v.string(),
    retailerSlug: v.optional(v.string()),
    startsAt: v.number(),
    endsAt: v.number(),
    kind: v.union(v.literal("national"), v.literal("retailer"), v.literal("brand")),
    dateConfidence: v.union(v.literal("confirmed"), v.literal("estimated")),
    notes: v.optional(v.string()),
  })
    .index("by_startsAt", ["startsAt"])
    .index("by_series_and_startsAt", ["series", "startsAt"]),

  // Compact text + numbers the agent can read instead of raw points. Recomputed on demand.
  priceDigests: defineTable({
    productId: v.id("products"),
    text: v.string(),
    computedAt: v.number(),
    windowStart: v.number(),
    windowEnd: v.number(),
    observationCount: v.number(),
    isSampleData: v.boolean(),
  }).index("by_productId", ["productId"]),

  // ---- Watchlist & monitoring (convex/watchlist, convex/monitoring) ----
  ...watchlistTables,
});
