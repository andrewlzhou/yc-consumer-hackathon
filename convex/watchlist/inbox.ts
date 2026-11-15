import { v } from "convex/values";
import { mutation, query } from "../_generated/server";

// Notifications the app has not acknowledged yet. This is the fallback path: the app subscribes to this live
// query and raises a local notification for each new row, so it works without APNs.
export const pending = query({
  args: { deviceId: v.string() },
  handler: async (ctx, args) => {
    const rows = await ctx.db
      .query("notificationLog")
      .withIndex("by_device_and_created", (q) => q.eq("deviceId", args.deviceId))
      .order("desc")
      .take(50);
    return rows
      .filter((r) => r.status === "sent" && !r.acknowledged)
      .map((r) => ({ id: r._id, productId: r.productId, title: r.title, body: r.body, price: r.price, verdict: r.verdict, trigger: r.trigger, simulated: r.simulated, channel: r.channel, createdAt: r.createdAt }));
  },
});

export const acknowledge = mutation({
  args: { deviceId: v.string(), ids: v.array(v.id("notificationLog")) },
  handler: async (ctx, args) => {
    for (const id of args.ids.slice(0, 50)) {
      const row = await ctx.db.get(id);
      if (row && row.deviceId === args.deviceId) await ctx.db.patch(id, { acknowledged: true });
    }
    return null;
  },
});
