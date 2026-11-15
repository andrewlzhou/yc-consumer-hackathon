import { ConvexError, v } from "convex/values";
import { internalMutation } from "../_generated/server";

// Stores the APNs token for a device. Only the fields sent are changed: omitting apnsToken keeps the stored token,
// null clears it. Debug builds run from Xcode use the sandbox environment, TestFlight and App Store use production.
export const register = internalMutation({
  args: { deviceId: v.string(), apnsToken: v.optional(v.union(v.string(), v.null())), environment: v.optional(v.union(v.literal("sandbox"), v.literal("production"))) },
  handler: async (ctx, args) => {
    if (args.deviceId.length < 8 || args.deviceId.length > 128) throw new ConvexError("deviceId must be 8-128 characters");
    if (typeof args.apnsToken === "string" && !/^[0-9a-fA-F]{32,200}$/.test(args.apnsToken)) throw new ConvexError("apnsToken must be hex");
    const existing = await ctx.db.query("devices").withIndex("by_device", (q) => q.eq("deviceId", args.deviceId)).unique();
    if (!existing) {
      if (!args.environment) throw new ConvexError("environment is required for a new device");
      await ctx.db.insert("devices", {
        deviceId: args.deviceId,
        apnsToken: args.apnsToken ?? undefined,
        environment: args.environment,
        updatedAt: Date.now(),
      });
      return null;
    }
    await ctx.db.patch(existing._id, {
      ...(args.apnsToken !== undefined && { apnsToken: args.apnsToken ?? undefined }),
      ...(args.environment && { environment: args.environment }),
      updatedAt: Date.now(),
    });
    return null;
  },
});

// Drops a token Apple says is dead, so it is not retried on every notification.
export const clearToken = internalMutation({
  args: { deviceId: v.string(), apnsToken: v.string() },
  handler: async (ctx, args) => {
    const existing = await ctx.db.query("devices").withIndex("by_device", (q) => q.eq("deviceId", args.deviceId)).unique();
    if (existing && existing.apnsToken === args.apnsToken) await ctx.db.patch(existing._id, { apnsToken: undefined, updatedAt: Date.now() });
    return null;
  },
});
