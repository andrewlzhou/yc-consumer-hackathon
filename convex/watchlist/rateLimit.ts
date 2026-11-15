import { v } from "convex/values";
import { internalMutation } from "../_generated/server";

// Fixed-window counter. Returns false once key has used its limit inside the current window.
export const hit = internalMutation({
  args: { key: v.string(), limit: v.number(), windowMs: v.number() },
  handler: async (ctx, args) => {
    const now = Date.now();
    const row = await ctx.db.query("rateLimits").withIndex("by_key", (q) => q.eq("key", args.key)).first();
    if (!row || now - row.windowStart >= args.windowMs) {
      if (row) await ctx.db.patch(row._id, { windowStart: now, count: 1 });
      else await ctx.db.insert("rateLimits", { key: args.key, windowStart: now, count: 1 });
      return true;
    }
    if (row.count >= args.limit) return false;
    await ctx.db.patch(row._id, { count: row.count + 1 });
    return true;
  },
});
