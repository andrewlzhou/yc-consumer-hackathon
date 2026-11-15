import { v } from "convex/values";
import { internalMutation, internalQuery } from "./_generated/server";

export const get = internalQuery({
  args: { key: v.string() },
  handler: async (ctx, { key }) =>
    ctx.db.query("products").withIndex("by_key", (q) => q.eq("key", key)).unique(),
});

export const upsert = internalMutation({
  args: { key: v.string(), name: v.string(), result: v.any() },
  handler: async (ctx, { key, name, result }) => {
    const existing = await ctx.db.query("products").withIndex("by_key", (q) => q.eq("key", key)).unique();
    if (existing) await ctx.db.patch(existing._id, { name, result, updatedAt: Date.now() });
    else await ctx.db.insert("products", { key, name, result, updatedAt: Date.now() });
  },
});

export const listRecent = internalQuery({
  args: {},
  handler: async (ctx) => {
    const rows = await ctx.db.query("products").order("desc").take(100);
    return rows.map((r) => ({ key: r.key, result: r.result }));
  },
});
