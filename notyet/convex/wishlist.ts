import { v } from "convex/values";
import { internalMutation, internalQuery } from "./_generated/server";

// Save (or update) a tracked item. Saving twice just updates the need-by date.
export const add = internalMutation({
  args: { deviceId: v.string(), scanKey: v.string(), needBy: v.optional(v.string()) },
  handler: async (ctx, { deviceId, scanKey, needBy }) => {
    const scan = await ctx.db.query("scans").withIndex("by_key", (q) => q.eq("scanKey", scanKey)).unique();
    if (!scan?.result) throw new Error("Scan has no result yet");
    const r = scan.result;
    const fields = {
      productName: r.product?.name ?? "Saved item",
      buyDate: r.waitUntil ?? undefined,
      targetPrice: r.expectedPrice?.high ?? undefined,
      needBy: needBy || undefined,
    };
    const existing = await ctx.db
      .query("wishlist")
      .withIndex("by_device", (q) => q.eq("deviceId", deviceId))
      .filter((q) => q.eq(q.field("scanKey"), scanKey))
      .first();
    if (existing) {
      await ctx.db.patch(existing._id, fields);
      return existing._id;
    }
    return ctx.db.insert("wishlist", { deviceId, scanKey, ...fields });
  },
});

export const list = internalQuery({
  args: { deviceId: v.string() },
  handler: async (ctx, { deviceId }) =>
    ctx.db.query("wishlist").withIndex("by_device", (q) => q.eq("deviceId", deviceId)).collect(),
});

// Everything still inside its need-by window, for the daily re-check.
export const listActive = internalQuery({
  args: {},
  handler: async (ctx) => {
    const today = new Date(Date.now()).toISOString().slice(0, 10);
    const all = await ctx.db.query("wishlist").take(200);
    return all.filter((w) => !w.needBy || w.needBy >= today);
  },
});

export const recordCheck = internalMutation({
  args: { id: v.id("wishlist"), price: v.number(), retailer: v.string() },
  handler: async (ctx, { id, price, retailer }) => {
    const w = await ctx.db.get(id);
    if (!w) return;
    await ctx.db.patch(id, {
      lastPrice: price,
      lastRetailer: retailer,
      lastChecked: Date.now(),
      dropped: w.targetPrice != null ? price <= w.targetPrice : false,
    });
  },
});
