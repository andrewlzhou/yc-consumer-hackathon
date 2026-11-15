import { v } from "convex/values";
import { internal } from "../_generated/api";
import { internalAction } from "../_generated/server";
import { evaluate } from "./evaluate";
import type { ProductSnapshot } from "./ports";

// Demo helper. Run from the CLI:
//   npx convex run monitoring/simulate:dropPrice '{"deviceId":"...","productId":"...","price":79.99}'
// Pretends the product now costs "price", judges it for that one device and sends if it qualifies.
// Nothing is written to price history and the watcher's baseline is left alone; every title starts [Simulated].
// Previous-low facts come from real rows only, so on a product with only seeded history set a target price.
export const dropPrice = internalAction({
  args: { deviceId: v.string(), productId: v.id("products"), price: v.number() },
  handler: async (ctx, args): Promise<Awaited<ReturnType<typeof evaluate>>> => {
    const watchers = await ctx.runQuery(internal.watchlist.items.watchersOf, { productId: args.productId });
    const mine = watchers.find((w) => w.deviceId === args.deviceId);
    if (!mine) throw new Error("that device is not watching this product");
    const real: ProductSnapshot | null = await ctx.runAction(internal.monitoring.ports.getSnapshot, { productId: args.productId });
    if (!real) throw new Error("no fresh current price for this product; scan it or refresh prices first");
    const snapshot = {
      ...real.snapshot,
      currentPrice: args.price,
      priceSource: "simulated" as const,
      reason: "Simulated price drop for demo. " + real.snapshot.reason,
    };
    return await evaluate(ctx, {
      productId: args.productId,
      title: real.title,
      snapshot,
      simulate: { deviceId: args.deviceId, baseline: { price: real.snapshot.currentPrice, verdict: real.snapshot.verdict } },
    });
  },
});
