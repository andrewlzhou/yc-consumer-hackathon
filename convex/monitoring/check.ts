import { v } from "convex/values";
import { internal } from "../_generated/api";
import { internalAction, internalMutation } from "../_generated/server";
import { evaluate } from "./evaluate";
import type { ProductSnapshot } from "./ports";
import { snapshotV } from "./state";

// One scheduled task per watched product: refresh, analyze, then decide for every device watching it.
export const checkProduct = internalAction({
  args: { productId: v.id("products") },
  handler: async (ctx, args): Promise<Awaited<ReturnType<typeof evaluate>>> => {
    const { title, snapshot }: ProductSnapshot = await ctx.runAction(internal.monitoring.ports.getSnapshot, { productId: args.productId });
    return await evaluate(ctx, { productId: args.productId, title, snapshot });
  },
});

// Decision step on its own, for callers that already hold a snapshot (tests, the simulated drop).
export const evaluateSnapshot = internalAction({
  args: { productId: v.id("products"), title: v.string(), snapshot: snapshotV, simulateDeviceId: v.optional(v.string()) },
  handler: async (ctx, args) => {
    return await evaluate(ctx, {
      productId: args.productId,
      title: args.title,
      snapshot: args.snapshot,
      simulate: args.simulateDeviceId ? { deviceId: args.simulateDeviceId } : undefined,
    });
  },
});

// Cron entry: one task per distinct watched product, staggered so a sweep does not hit data sources at once.
export const sweep = internalMutation({
  args: {},
  handler: async (ctx) => {
    const items = await ctx.db.query("watchItems").take(2000);
    const products = [...new Set(items.map((i) => i.productId))];
    for (const [i, productId] of products.entries()) {
      await ctx.scheduler.runAfter(i * 1000, internal.monitoring.check.checkProduct, { productId });
    }
    return products.length;
  },
});
