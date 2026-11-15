import { v } from "convex/values";
import { internalMutation, internalQuery, query } from "./_generated/server";

export const create = internalMutation({
  args: {
    deviceId: v.string(),
    scanKey: v.string(),
    imageId: v.optional(v.id("_storage")),
    query: v.optional(v.string()),
    needBy: v.optional(v.string()),
  },
  handler: async (ctx, args) =>
    ctx.db.insert("scans", { ...args, status: "working", step: "Finding the product…" }),
});

export const get = internalQuery({
  args: { id: v.id("scans") },
  handler: async (ctx, { id }) => ctx.db.get(id),
});

export const byKey = internalQuery({
  args: { scanKey: v.string() },
  handler: async (ctx, { scanKey }) =>
    ctx.db.query("scans").withIndex("by_key", (q) => q.eq("scanKey", scanKey)).unique(),
});

// Hackathon shortcut: patch any fields on a scan.
export const patch = internalMutation({
  args: { id: v.id("scans"), fields: v.any() },
  handler: async (ctx, { id, fields }) => ctx.db.patch(id, fields),
});

// Public query, for when you switch the app to the Convex Swift client for live updates.
export const getByKey = query({
  args: { scanKey: v.string() },
  handler: async (ctx, { scanKey }) => {
    const s = await ctx.db.query("scans").withIndex("by_key", (q) => q.eq("scanKey", scanKey)).unique();
    if (!s) return null;
    return { status: s.status, step: s.step, quick: s.quick?.public ?? null, result: s.result ?? null, error: s.error ?? null };
  },
});

// History tab: newest first, with tracking info joined in.
export const listByDevice = internalQuery({
  args: { deviceId: v.string() },
  handler: async (ctx, { deviceId }) => {
    const rows = await ctx.db
      .query("scans")
      .withIndex("by_device", (q) => q.eq("deviceId", deviceId))
      .order("desc")
      .take(50);
    const saved = await ctx.db.query("wishlist").withIndex("by_device", (q) => q.eq("deviceId", deviceId)).collect();
    const savedByKey = new Map(saved.map((w) => [w.scanKey, w]));
    return rows.map((s) => {
      const w = savedByKey.get(s.scanKey);
      return {
        scanKey: s.scanKey,
        status: s.status,
        createdAt: s._creationTime,
        productName: s.result?.product?.name ?? s.quick?.public?.productName ?? null,
        verdict: s.result?.verdict ?? s.quick?.public?.verdict ?? null,
        oneLiner: s.result?.oneLiner ?? s.quick?.public?.oneLiner ?? null,
        retailer: s.result?.whereToBuy?.retailer ?? s.quick?.public?.retailer ?? null,
        currentPrice: s.result?.currentPrice ?? null,
        saved: !!w,
        needBy: w?.needBy ?? s.needBy ?? null,
        lastPrice: w?.lastPrice ?? null,
        dropped: w?.dropped ?? false,
      };
    });
  },
});
