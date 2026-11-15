/// <reference types="vite/client" />
import { convexTest } from "convex-test";
import { expect, test } from "vitest";
import schema from "./schema";

const modules = import.meta.glob("./**/*.ts");

test("schema accepts a product with an observation and a missing out-of-stock price", async () => {
  const t = convexTest(schema, modules);
  const rows = await t.run(async (ctx) => {
    const productId = await ctx.db.insert("products", {
      title: "Smoke Test Widget",
      brand: "Acme",
      category: "test",
      familyKey: "acme-widget",
      specs: { color: "black" },
      aliases: [],
      searchText: "Smoke Test Widget Acme",
      isSample: true,
      provisional: false,
    });
    await ctx.db.insert("priceObservations", {
      productId,
      retailerSlug: "target",
      price: 19.99,
      inStock: true,
      observedAt: Date.UTC(2026, 10, 1),
      source: "seed",
    });
    await ctx.db.insert("priceObservations", {
      productId,
      retailerSlug: "target",
      inStock: false,
      observedAt: Date.UTC(2026, 10, 2),
      source: "seed",
    });
    return ctx.db
      .query("priceObservations")
      .withIndex("by_product_and_observedAt", (q) => q.eq("productId", productId))
      .take(10);
  });
  expect(rows.map((r) => r.price ?? null)).toEqual([19.99, null]);
});
