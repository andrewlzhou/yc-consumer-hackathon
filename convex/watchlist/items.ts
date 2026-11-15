import { ConvexError, v } from "convex/values";
import { internal } from "../_generated/api";
import { internalMutation, internalQuery } from "../_generated/server";
import { defaultPrefs } from "../monitoring/policy";
import { prefsV } from "./tables";

const MAX_ITEMS_PER_DEVICE = 100;

function assertDeviceId(deviceId: string) {
  if (deviceId.length < 8 || deviceId.length > 128) throw new ConvexError("deviceId must be 8-128 characters");
}

// Saves or edits a watched product. targetPrice null clears the target; omitted fields stay as they are.
export const save = internalMutation({
  args: {
    deviceId: v.string(),
    productId: v.id("products"),
    targetPrice: v.optional(v.union(v.number(), v.null())),
    prefs: v.optional(prefsV.partial()),
  },
  handler: async (ctx, args) => {
    assertDeviceId(args.deviceId);
    if (typeof args.targetPrice === "number" && !(args.targetPrice > 0)) throw new ConvexError("targetPrice must be positive");
    const existing = await ctx.db
      .query("watchItems")
      .withIndex("by_device_and_product", (q) => q.eq("deviceId", args.deviceId).eq("productId", args.productId))
      .unique();
    if (existing) {
      await ctx.db.patch(existing._id, {
        ...(args.targetPrice !== undefined && { targetPrice: args.targetPrice ?? undefined }),
        ...(args.prefs && { prefs: { ...existing.prefs, ...args.prefs } }),
      });
      return existing._id;
    }
    const count = (await ctx.db.query("watchItems").withIndex("by_device_and_product", (q) => q.eq("deviceId", args.deviceId)).take(MAX_ITEMS_PER_DEVICE)).length;
    if (count >= MAX_ITEMS_PER_DEVICE) throw new ConvexError("watchlist is full");
    const id = await ctx.db.insert("watchItems", {
      deviceId: args.deviceId,
      productId: args.productId,
      targetPrice: args.targetPrice ?? undefined,
      prefs: { ...defaultPrefs(), ...args.prefs },
      createdAt: Date.now(),
    });
    await ctx.scheduler.runAfter(0, internal.monitoring.check.checkProduct, { productId: args.productId, refresh: true });
    return id;
  },
});

export const remove = internalMutation({
  args: { deviceId: v.string(), productId: v.id("products") },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("watchItems")
      .withIndex("by_device_and_product", (q) => q.eq("deviceId", args.deviceId).eq("productId", args.productId))
      .unique();
    if (!existing) return false;
    await ctx.db.delete(existing._id);
    return true;
  },
});

export const list = internalQuery({
  args: { deviceId: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("watchItems")
      .withIndex("by_device_and_product", (q) => q.eq("deviceId", args.deviceId))
      .take(MAX_ITEMS_PER_DEVICE);
  },
});

export const watchersOf = internalQuery({
  args: { productId: v.id("products") },
  handler: async (ctx, args) => {
    return await ctx.db.query("watchItems").withIndex("by_product", (q) => q.eq("productId", args.productId)).take(500);
  },
});
