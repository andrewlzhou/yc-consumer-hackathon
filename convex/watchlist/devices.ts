import { ConvexError, v } from "convex/values";
import { mutation } from "../_generated/server";

// Stores the APNs token for a device. Debug builds run from Xcode use the sandbox environment.
export const register = mutation({
  args: { deviceId: v.string(), apnsToken: v.optional(v.string()), environment: v.union(v.literal("sandbox"), v.literal("production")) },
  handler: async (ctx, args) => {
    if (args.deviceId.length < 8 || args.deviceId.length > 128) throw new ConvexError("deviceId must be 8-128 characters");
    if (args.apnsToken !== undefined && !/^[0-9a-fA-F]{32,200}$/.test(args.apnsToken)) throw new ConvexError("apnsToken must be hex");
    const existing = await ctx.db.query("devices").withIndex("by_device", (q) => q.eq("deviceId", args.deviceId)).unique();
    const row = { deviceId: args.deviceId, apnsToken: args.apnsToken, environment: args.environment, updatedAt: Date.now() };
    if (existing) await ctx.db.replace(existing._id, row);
    else await ctx.db.insert("devices", row);
    return null;
  },
});
